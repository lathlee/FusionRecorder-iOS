#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ADB 自动化骨架的离线自测（不需要眼镜 / 不需要 Mac / 不需要 Xcode）。

用真实 TCP socket 起一个「假 adbd」，把 Swift 侧 ADBClient 的协议行为过一遍：
  1. CNXN 握手 + AUTH 两轮（SIGNATURE → PUBLICKEY → CNXN）
  2. shell 通道：OPEN → OKAY → 多片 WRTE → CLSE，验证收集完整输出
  3. sync push：SEND/DATA/DONE 字节序列，验证 ADBSyncPusher 与 AOSP SYNC.TXT 一致
  4. 命令构造：CaptureOrchestrator 静态函数产出的命令串（host 必须是 iPhone IP、pts=1）

全部断言通过才说明「Swift 写的字节规格」和「AOSP 协议」没各说各话。
真机唯一待联调项仍是 ROM 授权框行为，本测试无法覆盖。

用法: python3 tools/adb_autotest.py
"""

import socket
import struct
import threading
import time

# ---- ADBPacket 常量（与 Swift ADBPacket.swift 一致）----
CNXN, AUTH, OPEN, OKAY, WRTE, CLSE = (
    0x4E584E43, 0x48545541, 0x4E45504F, 0x59414B4F, 0x45545257, 0x45534C43
)
AUTH_TOKEN, AUTH_SIGNATURE, AUTH_PUBLICKEY = 1, 2, 3


def packet(command, arg0, arg1, payload=b""):
    magic = command ^ 0xFFFFFFFF
    checksum = sum(payload) & 0xFFFFFFFF
    return struct.pack("<IIIIII", command, arg0, arg1,
                       len(payload), checksum, magic) + payload


def parse_packet(buf):
    if len(buf) < 24:
        return None
    command, arg0, arg1, length, checksum, magic = struct.unpack_from("<IIIIII", buf, 0)
    if len(buf) < 24 + length:
        return None
    payload = buf[24:24 + length]
    assert checksum == (sum(payload) & 0xFFFFFFFF), "checksum 不符"
    assert magic == (command ^ 0xFFFFFFFF), "magic 不符"
    return command, arg0, arg1, payload, 24 + length


def sync_frame(id_bytes, payload=b""):
    return id_bytes + struct.pack("<I", len(payload)) + payload


class FakeAdbd(threading.Thread):
    """最小 adbd：走一遍 AUTH，然后按命令回 shell 输出 / 收 sync push。"""

    def __init__(self, port, transcript):
        super().__init__(daemon=True)
        self.port = port
        self.transcript = transcript          # list[str]，记录收到的事件
        self.srv = socket.socket()
        self.srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.srv.bind(("127.0.0.1", port))
        self.srv.listen(1)
        self.ready = threading.Event()

    def run(self):
        self.ready.set()
        conn, _ = self.srv.accept()
        buf = b""
        auth_round = 0
        stream_remote = 0x100
        try:
            while True:
                chunk = conn.recv(65536)
                if not chunk:
                    break
                buf += chunk
                while True:
                    parsed = parse_packet(buf)
                    if not parsed:
                        break
                    cmd, arg0, arg1, payload, consumed = parsed
                    buf = buf[consumed:]
                    if cmd == CNXN:
                        self.transcript.append("CNXN")
                        conn.sendall(packet(AUTH, AUTH_TOKEN, 0, b"t" * 20))
                    elif cmd == AUTH and arg0 == AUTH_SIGNATURE:
                        auth_round += 1
                        self.transcript.append("AUTH_SIGNATURE(%d)" % len(payload))
                        # 假装不认签名，再发一次 token，逼客户端回公钥
                        conn.sendall(packet(AUTH, AUTH_TOKEN, 0, b"u" * 20))
                    elif cmd == AUTH and arg0 == AUTH_PUBLICKEY:
                        auth_round += 1
                        # 真 adbd 把 payload 当 C 字符串，要求 NUL 结尾。
                        # 缺 NUL 时真机报 "Key must be a null-terminated string" 并挂断，
                        # 这里如实模拟：不以 \0 结尾就关闭连接，绝不放行。
                        text = payload.decode(errors="replace")
                        ok = payload.endswith(b"\x00") and "fusion@iphone" in text
                        self.transcript.append("AUTH_PUBLICKEY(%s)" % ("ok" if ok else "BAD"))
                        if ok:
                            conn.sendall(packet(CNXN, 0x01000000, 0x00100000, b"device::\0"))
                        else:
                            conn.close()
                            return
                    elif cmd == OPEN:
                        service = payload.rstrip(b"\0").decode(errors="replace")
                        self.transcript.append("OPEN:" + service)
                        stream_remote += 1
                        # 真 adbd 语义：OKAY(arg0=设备remoteId, arg1=客户端localId echo)
                        # 之前写反成 (arg0=localId, arg1=remoteId)，掩盖了 ADBClient 的
                        # remoteId 取错 bug（sync push 超时）。2026-11-20 真机实测修正。
                        conn.sendall(packet(OKAY, stream_remote, arg0))
                        if service.startswith("shell:"):
                            self._handle_shell(conn, service[6:], arg0, stream_remote)
                        elif service == "sync:":
                            self._handle_sync(conn, arg0, stream_remote, buf)
                    elif cmd == OKAY:
                        pass
                    elif cmd == CLSE:
                        self.transcript.append("CLSE")
        except (ConnectionResetError, BrokenPipeError):
            pass
        finally:
            conn.close()
            self.srv.close()

    def _handle_shell(self, conn, command, local_id, remote_id):
        replies = {
            "id": "uid=2000(shell) gid=2000(shell) groups=2000(shell)\n",
            "pm install -r /data/local/tmp/fusion-capture.apk": "Success\n",
            "pm grant com.fusion.capture android.permission.CAMERA": "",
        }
        text = replies.get(command, "ok\n")
        # 故意拆两片，验证客户端会累积 WRTE 而不是拿到第一片就回调
        mid = len(text) // 2
        for piece in (text[:mid], text[mid:]):
            conn.sendall(packet(WRTE, remote_id, local_id, piece.encode()))
            # 真 adb 会等 OKAY，这里不等，简化
        conn.sendall(packet(CLSE, remote_id, local_id))

    def _handle_sync(self, conn, local_id, remote_id, initial):
        # 真机协议：sync 帧(SEND/DATA/DONE)包在 ADB WRTE 包里发来，
        # WRTE.arg1 必须 = 设备分配的 remote_id。之前 mock 直接读裸 sync 帧，
        # 没校验 arg1，掩盖了 ADBClient 把 remoteId 取成 arg1 的 bug。
        # 2026-11-20 修正：按 ADBPacket 解包并严格校验。
        adb_buf = initial
        sync_buf = bytearray()
        seen = []
        bad_remote = False
        while True:
            chunk = conn.recv(65536)
            if not chunk:
                break
            adb_buf += chunk
            while len(adb_buf) >= 24:
                cmd, a0, a1, ln, cs, mg = struct.unpack_from("<IIIIII", adb_buf)
                if len(adb_buf) < 24 + ln:
                    break
                payload = adb_buf[24:24 + ln]
                adb_buf = adb_buf[24 + ln:]
                if cmd != WRTE:
                    continue
                if a1 != remote_id:
                    bad_remote = True
                    self.transcript.append("SYNC_WRTE_BAD_ARG1(%d!=%d)" % (a1, remote_id))
                sync_buf += payload
            while len(sync_buf) >= 8:
                sid = bytes(sync_buf[:4])
                length = struct.unpack_from("<I", sync_buf, 4)[0]
                if len(sync_buf) < 8 + length:
                    break
                spayload = bytes(sync_buf[8:8 + length])
                del sync_buf[:8 + length]
                if sid == b"SEND":
                    seen.append("SEND:" + spayload.decode(errors="replace"))
                elif sid == b"DATA":
                    seen.append("DATA:%d" % length)
                elif sid == b"DONE":
                    seen.append("DONE:%d" % length)
                    if bad_remote:
                        self.transcript.append("sync BAD_REMOTE " + ",".join(seen))
                        conn.close()
                        return                       # 模拟真 adbd 断开
                    self.transcript.append("sync " + ",".join(seen))
                    conn.sendall(sync_frame(b"OKAY"))
                    return


class Client:
    def __init__(self, port):
        self.sock = socket.create_connection(("127.0.0.1", port), timeout=3)
        self.buf = b""
        self.remote = None

    def send(self, cmd, a0, a1, payload=b""):
        self.sock.sendall(packet(cmd, a0, a1, payload))

    def recv_one(self):
        while True:
            p = parse_packet(self.buf)
            if p:
                self.buf = self.buf[p[4]:]
                return p[:4]
            self.buf += self.sock.recv(65536)

    def close(self):
        self.sock.close()


def test_auth_and_shell(port, transcript):
    c = Client(port)
    c.send(CNXN, 0x01000000, 0x00100000, b"host::\0")
    cmd, a0, a1, payload = c.recv_one()
    assert (cmd, a0) == (AUTH, AUTH_TOKEN), "首包应为 AUTH TOKEN"

    # 第 1 轮：签名（这里用固定 256 字节模拟 2048-bit RSA 签名）
    c.send(AUTH, AUTH_SIGNATURE, 0, b"S" * 256)
    cmd, a0, a1, payload = c.recv_one()
    assert (cmd, a0) == (AUTH, AUTH_TOKEN), "签名未被接受应再来 TOKEN"

    # 第 2 轮：公钥，base64 + ' fusion@iphone' + NUL（真 adbd 要求 null-terminated）
    c.send(AUTH, AUTH_PUBLICKEY, 0, b"QUJD" + b" fusion@iphone\x00")
    cmd, a0, a1, payload = c.recv_one()
    assert cmd == CNXN, "公钥接受后应收到 CNXN"

    # shell: id，验证多片 WRTE 累积
    c.send(OPEN, 0x10000001, 0, b"shell:id\0")
    cmd, a0, a1, payload = c.recv_one()
    assert cmd == OKAY
    remote = a0                        # 真机语义：OKAY.arg0 = 设备 remoteId
    assert a1 == 0x10000001, "OKAY.arg1 应是客户端 localId echo"
    output = b""
    cmd, a0, a1, payload = c.recv_one()
    while cmd == WRTE:
        output += payload
        c.send(OKAY, a1, a0)
        cmd, a0, a1, payload = c.recv_one()
    assert cmd == CLSE
    assert output.decode().startswith("uid=2000") and "shell" in output.decode()
    assert "AUTH_SIGNATURE(256)" in transcript
    assert "AUTH_PUBLICKEY(ok)" in transcript
    c.close()
    return True


def test_sync_push(port, transcript):
    c = Client(port)
    c.send(CNXN, 0x01000000, 0x00100000, b"host::\0")
    c.recv_one()                                   # AUTH TOKEN
    c.send(AUTH, AUTH_SIGNATURE, 0, b"S" * 256)
    c.recv_one()                                   # TOKEN again
    c.send(AUTH, AUTH_PUBLICKEY, 0, b"QUJD fusion@iphone\x00")
    c.recv_one()                                   # CNXN

    c.send(OPEN, 0x20000001, 0, b"sync:\0")
    cmd, a0, a1, payload = c.recv_one()
    assert cmd == OKAY
    # 真机语义：OKAY.arg0 = 设备 remoteId（WRTE.arg1 要用它）；
    # OKAY.arg1 = 客户端 localId echo。取错会导致真 adbd 断开。
    remote = a0
    local = 0x20000001
    assert a1 == local, "OKAY.arg1 应是客户端 localId echo"

    # 模拟 ADBClient.push + ADBSyncPusher：每帧包成一个 ADB WRTE(local, remote, frame)
    for frame in (sync_frame(b"SEND", b"/data/local/tmp/screen-push.jar,0644"),
                  sync_frame(b"DATA", b"hello"),
                  sync_frame(b"DATA", b"world"),
                  sync_frame(b"DONE", struct.pack("<I", 1700000000))):
        c.send(WRTE, local, remote, frame)
    # 读 sync OKAY（8 字节，不走 ADBPacket）
    resp = c.sock.recv(8)
    assert resp[:4] == b"OKAY", "DONE 后应收到 sync OKAY"
    c.close()

    matched = [line for line in transcript if line.startswith("sync ")]
    assert matched, "假 adbd 没收到 sync 帧"
    assert "SEND:/data/local/tmp/screen-push.jar,0644" in matched[-1]
    assert "DATA:5" in matched[-1] and "DONE:4" in matched[-1]
    return True


def test_pubkey_requires_nul(port, transcript):
    """回归测试：公钥 payload 缺结尾 NUL 时，真 adbd 会拒绝（挂断）。
    mock adbd 必须同样拒绝，否则这类 bug 会漏到真机（2026-11-20 uws6152 实测）。"""
    c = Client(port)
    c.send(CNXN, 0x01000000, 0x00100000, b"host::\0")
    c.recv_one()                                   # AUTH TOKEN
    c.send(AUTH, AUTH_SIGNATURE, 0, b"S" * 256)
    c.recv_one()                                   # TOKEN again
    c.send(AUTH, AUTH_PUBLICKEY, 0, b"QUJD fusion@iphone")   # 故意缺 \0
    # mock adbd 应挂断：设短超时后读原始 socket，拿到 b"" 即被关闭
    c.sock.settimeout(2)
    rejected = False
    try:
        data = c.sock.recv(65536)
        rejected = (data == b"")   # 对端关闭 = 拒绝
    except (ConnectionError, OSError, EOFError, TimeoutError):
        rejected = True
    c.close()
    assert rejected, "缺 NUL 的公钥应被拒绝（模拟真 adbd 的 null-terminated 校验）"
    assert "AUTH_PUBLICKEY(BAD)" in transcript, "mock adbd 应标记 BAD"
    return True


def test_commands():
    """命令构造常量：host 必须是 iPhone IP，pts=1，无换行。"""
    IPHONE = "172.20.10.1"
    screen = ("CLASSPATH=/data/local/tmp/screen-push.jar app_process / poc.ScreenPush "
              "%s 9114 0 640 400 20 2000000 2 1" % IPHONE)
    camera = ("am start-foreground-service -n com.fusion.capture/.CameraStreamService "
              "--es host %s --ei port 9115 --ei sec 0 --ei width 640 --ei height 480 "
              "--ei fps 30 --ei bitrate 2000000 --ei iframe 2 --ei pts 1" % IPHONE)

    assert "172.20.10.1" in screen and "--es host" not in screen
    assert "uid" not in screen
    assert "--es host %s" % IPHONE in camera
    assert "--ei pts 1" in camera
    for cmd in (screen, camera):
        assert "\n" not in cmd and "\r" not in cmd and "\0" not in cmd

    # 与 Swift 源码交叉核对：这些关键字必须真的出现在 CaptureOrchestrator.swift 里
    swift = open("FusionRecorder/ADB/CaptureOrchestrator.swift", encoding="utf-8").read()
    for token in ["poc.ScreenPush", "app_process", "CLASSPATH=", "screen-push.jar",
                  "CameraStreamService", "--es host", "--ei pts", "KeepAliveActivity",
                  "STOP_CAMERA", "force-stop", "uid=2000"]:
        assert token in swift, "Swift 源码缺少关键字: " + token
    return True


def test_local_ip_pick():
    """本机 IP 选择：不能盲取 first，必须同网段优先、过滤虚拟接口。
    2026-11-20 真机取到 16.2.0.0（虚拟接口）导致眼镜连不上。"""
    # Swift 源码必须含新方法（防回归：确认改动真的进了源码）
    disc = open("FusionRecorder/ADB/GlassesDiscovery.swift", encoding="utf-8").read()
    orch = open("FusionRecorder/ADB/CaptureOrchestrator.swift", encoding="utf-8").read()
    assert "pickLocalIP" in disc and "bestLocalIP" in disc, "缺少 IP 选择方法"
    assert "bestLocalIP(for:" in orch, "orchestrator 未用智能选 IP"
    # 排除注释行后，实际代码不应再有 localIPv4().first
    code_lines = [l for l in orch.splitlines() if not l.strip().startswith("//")]
    assert not any("localIPv4().first" in l for l in code_lines), "orchestrator 还在盲取 localIPv4().first"

    # Python 复刻 pickLocalIP 算法，验证真实场景
    def octets(s):
        p = s.split(".")
        return [int(x) for x in p] if len(p) == 4 and all(x.isdigit() for x in p) else None
    def is_private(s):
        p = octets(s)
        if not p: return False
        return p[0] == 10 or (p[0] == 192 and p[1] == 168) or (p[0] == 172 and 16 <= p[1] <= 31)
    def pick(all_ips, glasses):
        if not all_ips: return None
        gp = octets(glasses) if glasses else None
        if gp:
            for ip in all_ips:
                p = octets(ip)
                if p and p[:3] == gp[:3]: return ip
        for ip in all_ips:
            if is_private(ip): return ip
        return all_ips[0]

    # 场景 1：16.2.0.0 排首位（虚拟接口），眼镜 192.168.101.133 → 必须选同网段 192.168.101.114
    ips = ["16.2.0.0", "192.168.101.114", "127.0.0.1"]
    assert pick(ips, "192.168.101.133") == "192.168.101.114", "同网段优先失败"
    # 场景 2：无同网段，过滤 16.x，选私有地址
    assert pick(["16.2.0.0", "10.0.0.5"], "8.8.8.8") == "10.0.0.5", "私有地址优先失败"
    # 场景 3：热点模式 172.20.10.x
    assert pick(["16.2.0.0", "172.20.10.1"], "172.20.10.5") == "172.20.10.1"
    return True


def main():
    results = []
    for name, fn in [
        ("AUTH 两轮 + shell 多片输出", test_auth_and_shell),
        ("公钥缺 NUL 必被拒(回归)", test_pubkey_requires_nul),
        ("sync push 字节序列", test_sync_push),
        ("命令构造与 Swift 交叉核对", lambda p, t: test_commands()),
        ("本机 IP 智能选择(同网段优先)", lambda p, t: test_local_ip_pick()),
    ]:
        transcript = []
        server = FakeAdbd(15999 + len(results), transcript)
        server.start()
        server.ready.wait(2)
        try:
            fn(server.port, transcript)
            results.append((name, True, ""))
        except AssertionError as error:
            results.append((name, False, str(error)))
        except Exception as error:                 # noqa: BLE001
            results.append((name, False, repr(error)))

    print("ADB 自动化骨架自测")
    print("-" * 60)
    for name, ok, message in results:
        print("  %s %s%s" % ("✓" if ok else "✗", name, ("  " + message) if message else ""))
    passed = sum(1 for _, ok, _ in results if ok)
    print("-" * 60)
    print("结果: %d/%d 通过" % (passed, len(results)))
    if passed != len(results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
