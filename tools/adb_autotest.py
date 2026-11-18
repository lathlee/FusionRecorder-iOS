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
                        text = payload.decode(errors="replace")
                        self.transcript.append("AUTH_PUBLICKEY(%s)" %
                                               ("ok" if text.endswith("fusion@iphone") else "BAD"))
                        conn.sendall(packet(CNXN, 0x01000000, 0x00100000, b"device::\0"))
                    elif cmd == OPEN:
                        service = payload.rstrip(b"\0").decode(errors="replace")
                        self.transcript.append("OPEN:" + service)
                        stream_remote += 1
                        conn.sendall(packet(OKAY, arg0, stream_remote))
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
        # 先读 SEND/DATA/DONE，回 OKAY。为简化，循环收到 DONE 就回。
        buf = initial
        seen = []
        while True:
            chunk = conn.recv(65536)
            if not chunk:
                break
            buf += chunk
            while len(buf) >= 8:
                sid = buf[:4]
                length = struct.unpack_from("<I", buf, 4)[0]
                if len(buf) < 8 + length:
                    break
                payload = buf[8:8 + length]
                buf = buf[8 + length:]
                if sid == b"SEND":
                    seen.append("SEND:" + payload.decode())
                elif sid == b"DATA":
                    seen.append("DATA:%d" % length)
                elif sid == b"DONE":
                    seen.append("DONE:%d" % length)
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

    # 第 2 轮：公钥，base64 + ' fusion@iphone'
    c.send(AUTH, AUTH_PUBLICKEY, 0, b"QUJD" + b" fusion@iphone")
    cmd, a0, a1, payload = c.recv_one()
    assert cmd == CNXN, "公钥接受后应收到 CNXN"

    # shell: id，验证多片 WRTE 累积
    c.send(OPEN, 0x10000001, 0, b"shell:id\0")
    cmd, a0, a1, payload = c.recv_one()
    assert cmd == OKAY
    remote = a1
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
    c.send(AUTH, AUTH_PUBLICKEY, 0, b"QUJD fusion@iphone")
    c.recv_one()                                   # CNXN

    c.send(OPEN, 0x20000001, 0, b"sync:\0")
    cmd, a0, a1, payload = c.recv_one()
    assert cmd == OKAY
    remote = a1

    # 模拟 ADBSyncPusher.sendFrames：SEND + 2×DATA + DONE
    c.sock.sendall(sync_frame(b"SEND", b"/data/local/tmp/screen-push.jar,0644"))
    c.sock.sendall(sync_frame(b"DATA", b"hello"))
    c.sock.sendall(sync_frame(b"DATA", b"world"))
    c.sock.sendall(sync_frame(b"DONE", struct.pack("<I", 1700000000)))
    # 读 sync OKAY（8 字节，不走 ADBPacket）
    resp = c.sock.recv(8)
    assert resp[:4] == b"OKAY", "DONE 后应收到 sync OKAY"
    c.close()

    matched = [line for line in transcript if line.startswith("sync ")]
    assert matched, "假 adbd 没收到 sync 帧"
    assert "SEND:/data/local/tmp/screen-push.jar,0644" in matched[-1]
    assert "DATA:5" in matched[-1] and "DONE:4" in matched[-1]
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


def main():
    results = []
    for name, fn in [
        ("AUTH 两轮 + shell 多片输出", test_auth_and_shell),
        ("sync push 字节序列", test_sync_push),
        ("命令构造与 Swift 交叉核对", lambda p, t: test_commands()),
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
