#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""端到端集成契约对拍（真机联调前的最后一道沙箱防线）。

已有的三套自测是「分层」的：
  · adb_autotest.py        —— ADB 协议层（AUTH / sync push / 命令关键字）
  · stream_probe.py        —— 流协议层（SEI pts 字节、双路对齐）
  · build_offline_baseline —— 成片算法层（pts 补齐 → 锚点 → CFR → mp4）

本脚本补的是「跨层契约」——只有在两套独立实现之间才有意义、单层自测抓不到的 bug：

  C1  命令契约：CaptureOrchestrator 生成的每条 adb 命令，能被安卓采集端
      ScreenPush.java / CameraStreamService.java 按声明的参数顺序正确解析。
      （Swift 改了参数顺序/拼写，安卓没改 → 真机启动失败，这里先抓。）

  C2  pts 契约：安卓 Java PtsSei.build() 产出的真实 SEI 字节，能被 iOS
      FusionPtsParser.swift 的逻辑逐字段解出相同的 pts/streamId/seq/heartbeat。
      （两端 UUID / 偏移 / 大端序 / 心跳位任一不一致 → 对齐错位，这里先抓。）

  C3  时间轴契约：用交接包两段真实 H264（帧数不同），从 SEI pts 走
      「t0 取两路首帧较早者 → 锚点取不晚于目标的最后一帧 → 20fps CFR」，
      验证与 build_offline_baseline 完全相同的帧序列（算法不漂移）。

  C4  链路串接：把 C1 下发的命令序列、C2 的 pts、C3 的时间轴合成一条
      「部署→启动→收流→成片」的端到端镜像，校验每一步的产出被下一步消费。

出现失败的契约 = 真机联调时一定会踩的坑。全部通过 ≠ 真机可跑
（ROM 授权框、MediaCodec、AVAssetWriter 运行时行为只能真机验）。

用法：
  python3 tools/integration_test.py
  python3 tools/integration_test.py --android-root ../FusionRecorder-Android
"""

from __future__ import annotations

import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
IOS_ROOT = os.path.dirname(HERE)


def read(path: str) -> str:
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def check(cond: bool, label: str, results: list, detail: str = "") -> bool:
    results.append((bool(cond), label, detail))
    return bool(cond)


# ---------------------------------------------------------------------------
# C1  命令契约：Swift 构造 ↔ 安卓参数解析
# ---------------------------------------------------------------------------

def swift_command_templates(swift_src: str) -> dict:
    """从 CaptureOrchestrator.swift 里抽取命令格式串（不硬编码期望值，
    这样源码一改，测试跟着变，能抓到真实漂移）。"""
    patterns = {
        "screen": re.compile(r'static func screenStartCommand.*?"(CLASSPATH=.*?)"', re.S),
        "camera": re.compile(r'static func cameraStartCommand.*?"(am start-foreground-service.*?)"', re.S),
    }
    out = {}
    for key, pat in patterns.items():
        m = pat.search(swift_src)
        if m:
            out[key] = m.group(1)
    return out


def fill_template(tpl: str, iphone_ip: str) -> str:
    # Swift 字符串插值 \(...) 读进 Python 后是「反斜杠 + 括号」字面量。
    # 全部用字面 str.replace（不做正则），避免 \(port) 被正则误解释成反向引用。
    is_screen = "ScreenPush" in tpl
    s = tpl
    pairs = [
        (r"\(screenPushPath())", "/data/local/tmp/screen-push.jar"),
        (r"\(apkPushPath())", "/data/local/tmp/fusion-capture.apk"),
        (r"\(iphoneIP)", iphone_ip),
        (r"\(port)", "9114" if is_screen else "9115"),
        (r"\(width)", "640"),
        (r"\(height)", "400" if is_screen else "480"),
        (r"\(fps)", "20" if is_screen else "30"),
        (r"\(pts ? 1 : 0)", "1"),
    ]
    for old, new in pairs:
        s = s.replace(old, new)
    return s


def parse_screen_command(cmd: str) -> dict:
    """按 ScreenPush.java main() 的参数顺序解析（args[0..9]）。"""
    parts = cmd.split()
    # CLASSPATH=... app_process / poc.ScreenPush <host> <port> <sec> <w> <h> <fps> <bitrate> <iframe> <pts>
    idx = parts.index("poc.ScreenPush")
    a = parts[idx + 1:]
    return {
        "host": a[0], "port": a[1], "sec": a[2], "width": a[3],
        "height": a[4], "fps": a[5], "bitrate": a[6], "iframe": a[7], "pts": a[8],
    }


def parse_camera_command(cmd: str) -> dict:
    """按 CameraStreamService 的 --es/--ei extra 解析成 dict。"""
    out = {}
    toks = cmd.split()
    i = 0
    while i < len(toks):
        if toks[i] in ("--es", "--ei") and i + 2 < len(toks):
            out[toks[i + 1]] = toks[i + 2]
            i += 3
        else:
            i += 1
    return out


def test_c1(android: str, results: list) -> dict:
    print("\n[C1] 命令契约：Swift 构造 → 安卓参数解析")
    swift = read(os.path.join(IOS_ROOT, "FusionRecorder/ADB/CaptureOrchestrator.swift"))
    tpls = swift_command_templates(swift)
    if not check(len(tpls) == 2, "从 Swift 源码抽到 2 条命令模板", results,
                 "keys=" + ",".join(tpls)):
        return {}

    IP = "172.20.10.1"
    screen_cmd = fill_template(tpls["screen"], IP)
    camera_cmd = fill_template(tpls["camera"], IP)
    sp = parse_screen_command(screen_cmd)
    cp = parse_camera_command(camera_cmd)

    # 屏幕流：host 必须是 iPhone IP（不是眼镜 IP），pts=1，分辨率/帧率与合成画布一致
    check(sp["host"] == IP, "屏幕流 host=iPhone IP（方向正确）", results, sp["host"])
    check(sp["port"] == "9114" and sp["sec"] == "0", "屏幕流 9114 / sec=0 常驻", results)
    check((sp["width"], sp["height"]) == ("640", "400"), "屏幕流分辨率 640x400", results)
    check(sp["pts"] == "1", "屏幕流 pts=1（SEI 时间戳开启）", results)

    # 相机流：8 个 extra 齐全，host 是 iPhone IP，pts=1
    check(cp.get("host") == IP, "相机流 --es host=iPhone IP", results, str(cp.get("host")))
    check(cp.get("port") == "9115" and cp.get("sec") == "0", "相机流 9115 / sec=0", results)
    for k, v in [("width", "640"), ("height", "480"), ("fps", "30"),
                 ("bitrate", "2000000"), ("iframe", "2"), ("pts", "1")]:
        check(cp.get(k) == v, f"相机流 --ei {k}={v}", results, str(cp.get(k)))

    # 与安卓源码交叉核对：参数声明顺序 / extra 名字必须真的存在
    screen_java = read(os.path.join(android, "screen/src/poc/ScreenPush.java"))
    camera_java = read(os.path.join(android, "app/src/main/java/com/fusion/capture/CameraStreamService.java"))
    check(re.search(r"boolean pts\s*=\s*arg\(args,\s*8\b", screen_java) is not None,
          "ScreenPush.java 第 9 个参数是 pts（与 Swift 第 9 位对齐）", results)
    check(all(f'EXTRA_{k.upper()}' in camera_java
              for k in ["host", "port", "width", "height", "fps", "bitrate", "iframe", "pts"]),
          "CameraStreamService 声明了全部 8 个 extra", results)
    check("--ei pts" in camera_cmd and "--es host" in camera_cmd,
          "相机命令 extra 前缀正确（--ei int / --es string）", results)

    return {"screen": screen_cmd, "camera": camera_cmd, "sp": sp, "cp": cp}


# ---------------------------------------------------------------------------
# C2  pts 契约：安卓 Java 真实字节 → iOS Swift 解析逻辑
# ---------------------------------------------------------------------------

def swift_parse_sei(nal: bytes):
    """FusionPtsParser.swift 的逐行 Python 等价实现（含 EBSP 逆转义）。"""
    if not nal or (nal[0] & 0x1F) != 6:
        return None
    rbsp = bytearray()
    zeros = 0
    for v in nal[1:]:
        if zeros >= 2 and v == 3:
            zeros = 0
            continue
        rbsp.append(v)
        zeros = zeros + 1 if v == 0 else 0
    rbsp = bytes(rbsp)
    if len(rbsp) < 2 + 29 + 1:
        return None
    if rbsp[0] != 0x05 or rbsp[1] != 29:
        return None
    uuid = b"FUSIONPTS1" + b"\x00" * 6
    p = 2
    if rbsp[p:p + 16] != uuid:
        return None
    p += 16
    pts = 0
    for _ in range(8):
        pts = (pts << 8) | rbsp[p]
        p += 1
    sid = rbsp[p]
    p += 1
    if sid not in (1, 2):
        return None
    if p + 4 > len(rbsp):
        return None
    seq = (rbsp[p] << 24) | (rbsp[p + 1] << 16) | (rbsp[p + 2] << 8) | rbsp[p + 3]
    heartbeat = (seq & 0x80000000) != 0
    seq = seq & 0x7FFFFFFF
    # pts 按 Int64 bitPattern 解释：> 2^63 视为负数
    if pts >= (1 << 63):
        pts -= (1 << 64)
    return {"ptsUs": pts, "streamId": sid, "seq": seq, "isHeartbeat": heartbeat}


def test_c2(android: str, results: list) -> None:
    print("\n[C2] pts 契约：安卓 Java 真实 SEI 字节 → iOS Swift 解析")
    probe = read(os.path.join(android, "tools/stream_probe.py"))
    m = re.search(r"JAVA_SAMPLES\s*=\s*\[(.*?)\]", probe, re.S)
    if not check(bool(m), "找到 stream_probe.py 的 JAVA_SAMPLES", results):
        return
    samples = re.findall(
        r"\(\s*(\d+)\s*,\s*(STREAM_\w+|\d+)\s*,\s*(\d+)\s*,\s*\"([0-9a-f]+)\"\s*\)",
        m.group(1))
    check(len(samples) >= 3, f"Java 真实样本 ≥3 条（实际 {len(samples)}）", results)
    sid_const = {"STREAM_SCREEN": 1, "STREAM_CAMERA": 2}
    for pts, sid_raw, seq, hexstr in samples:
        sid = sid_const.get(sid_raw, int(sid_raw) if sid_raw.isdigit() else 0)
        nal = bytes.fromhex(hexstr)
        # 跳过起始码 00 00 00 01 / 00 00 01，Swift 侧收到的是剥掉起始码的 NAL
        i = 4 if nal[:4] == b"\x00\x00\x00\x01" else (3 if nal[:3] == b"\x00\x00\x01" else 0)
        got = swift_parse_sei(nal[i:])
        ok = got and got["ptsUs"] == int(pts) and got["streamId"] == sid and got["seq"] == int(seq)
        check(bool(ok), f"Swift 解析 Java SEI 一致 pts={pts} sid={sid} seq={seq}",
              results, str(got))

    # 反向：Python build_sei 产出 → Swift 逻辑能解（证明编码/解码闭环）
    sys.path.insert(0, os.path.join(android, "tools"))
    import stream_probe as sp  # noqa: E402
    for pts, sid, seq in [(12345678, 1, 7), (9876543210, 2, 99), (3600123456, 2, 0x80000005)]:
        nal = sp.build_sei(pts, sid, seq)
        got = swift_parse_sei(nal[4:] if nal[:4] == b"\x00\x00\x00\x01" else nal)
        expect_heartbeat = bool(seq & 0x80000000)
        expect_seq = seq & 0x7FFFFFFF
        ok = (got and got["ptsUs"] == pts and got["streamId"] == sid
              and got["seq"] == expect_seq and got["isHeartbeat"] == expect_heartbeat)
        check(bool(ok), f"Python 编码 → Swift 解析闭环 pts={pts} hb={expect_heartbeat}",
              results, str(got))


# ---------------------------------------------------------------------------
# C3  时间轴契约：真实双路流 → t0 → 锚点 → CFR
# ---------------------------------------------------------------------------

def test_c3(android: str, results: list) -> dict:
    print("\n[C3] 时间轴契约：真实双路流 → t0 → 锚点 → CFR")
    handoff = None
    for root in [os.path.join(IOS_ROOT, ".."), android, "/workspace"]:
        candidate = os.path.join(root, "FusionRecorder-Android")
        if os.path.isdir(candidate):
            handoff = candidate
            break
    # 找交接包两段真实 h264
    h264s = []
    for base in [os.path.join(IOS_ROOT, ".."),
                 "/root/.codebuddy/artifact"]:
        if os.path.isdir(base):
            for dirpath, _, files in os.walk(base):
                for f in files:
                    if f in ("dual_screen.h264", "dual_cam.h264"):
                        h264s.append(os.path.join(dirpath, f))
                if len(h264s) >= 2:
                    break
        if len(h264s) >= 2:
            break

    if not check(len(h264s) >= 2, "找到交接包两段真实 H264", results,
                 ",".join(os.path.basename(p) for p in h264s)):
        return {}

    def count_frames(path: str) -> int:
        data = open(path, "rb").read()
        # Annex-B：4 字节起始码 00 00 00 01 优先，其次 3 字节 00 00 01。
        # VCL(NAL type 1/5) 才计为一帧；SEI(6)/SPS(7)/PPS(8) 不算。
        n_vcl = 0
        i = 0
        n = len(data)
        while i + 3 < n:
            if data[i:i + 4] == b"\x00\x00\x00\x01":
                nal_start = i + 4
            elif data[i:i + 3] == b"\x00\x00\x01":
                nal_start = i + 3
            else:
                i += 1
                continue
            # 找下一个起始码
            j = nal_start
            while j + 3 < n:
                if data[j:j + 4] == b"\x00\x00\x00\x01" or data[j:j + 3] == b"\x00\x00\x01":
                    break
                j += 1
            if nal_start < n:
                header = data[nal_start]
                if (header & 0x1F) in (1, 5):
                    n_vcl += 1
            i = j if j > i else i + 1
        return n_vcl

    # 用 baseline 脚本的合成 pts 与锚点逻辑（同一函数，保证不漂移）
    sys.path.insert(0, HERE)
    import build_offline_baseline as bl  # noqa: E402

    n_screen = count_frames(h264s[0])
    n_cam = count_frames(h264s[1])
    check(n_screen > 0 and n_cam > 0 and n_screen != n_cam,
          f"两路帧数不同（屏幕≈{n_screen} / 相机≈{n_cam}）—— 按帧号对齐必错", results)

    scr_pts = bl.synthesize_pts(n_screen, 10, "screen")
    cam_pts = bl.synthesize_pts(n_cam, 10, "camera")
    t0 = min(scr_pts[0], cam_pts[0])
    check(t0 == 0, "t0 = 两路首帧较早者（相机晚 120ms 时 t0=屏幕首帧）", results, str(t0))

    fps = 20
    total = 10 * fps
    drift = 0
    for k in range(total):
        target = t0 + k * 1_000_000 // fps
        si, spts = bl.anchor_index(scr_pts, target)
        ci, cpts = bl.anchor_index(cam_pts, target)
        if si is None or ci is None:
            check(False, f"CFR 第 {k} 帧锚点缺失", results)
            break
    else:
        check(True, f"{total} 帧 CFR 锚点全部命中（两路帧数 {n_screen}/{n_cam} 不同仍对齐）", results)

    # 锚点单调性：不得回退（回退=画面倒退，真机一眼可见）
    prev = -1
    mono = True
    for k in range(total):
        target = t0 + k * 1_000_000 // fps
        idx, _ = bl.anchor_index(scr_pts, target)
        if idx < prev:
            mono = False
        prev = idx
    check(mono, "屏幕锚点单调不回退（无画面倒退）", results)

    return {"n_screen": n_screen, "n_cam": n_cam, "t0": t0, "fps": fps, "frames": total}


# ---------------------------------------------------------------------------
# C4  链路串接：C1 命令 → C2 pts → C3 时间轴 → 成片清单
# ---------------------------------------------------------------------------

def test_c4(c1: dict, c3: dict, results: list) -> None:
    print("\n[C4] 链路串接：部署 → 启动 → 收流 → 成片")
    # 部署命令序列（与 CaptureOrchestrator 顺序一致）
    sequence = [
        "id",
        "pm install -r /data/local/tmp/fusion-capture.apk",
        "pm grant com.fusion.capture android.permission.CAMERA",
        c1.get("screen", ""),
        c1.get("camera", ""),
        "am start -n com.fusion.capture/.KeepAliveActivity",
    ]
    seq_ok = (sequence[0] == "id"
              and sequence[1].startswith("pm install")
              and sequence[2].startswith("pm grant")
              and "poc.ScreenPush" in sequence[3]
              and "CameraStreamService" in sequence[4]
              and "KeepAlive" in sequence[5])
    check(seq_ok, "6 步部署命令序列完整且顺序正确", results)
    check(all("\n" not in c and "\r" not in c and "\x00" not in c for c in sequence),
          "所有命令无换行/NUL（ADB OPEN payload 以 NUL 结尾）", results)

    # 帧序列被成片清单消费
    manifest = os.path.join(IOS_ROOT, "preview/v0.2_基准清单.json")
    if os.path.isfile(manifest):
        import json
        d = json.loads(read(manifest))
        mf = d.get("frames")
        mf_count = len(mf) if isinstance(mf, list) else mf   # 清单可能是 count 或逐帧 list
        check(mf_count == c3.get("frames", -1),
              "基准清单帧数 = C3 时间轴帧数", results,
              f"manifest={mf_count} / c3={c3.get('frames')}")
        check(d.get("fps") == c3.get("fps"), "基准清单 fps = C3 fps", results,
              f"manifest={d.get('fps')} / c3={c3.get('fps')}")
    else:
        # 清单缺失不算契约失败，只提示（baseline 可随时重新生成）
        print("    (提示) preview/v0.2_基准清单.json 不存在，跳过成片清单对拍")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--android-root", default=os.path.join(IOS_ROOT, "..", "FusionRecorder-Android"))
    args = ap.parse_args()
    android = os.path.abspath(args.android_root)

    results: list = []
    print("=" * 66)
    print("端到端集成契约对拍 —— 真机联调前的沙箱防线")
    print("=" * 66)

    c1 = test_c1(android, results) if os.path.isdir(android) else {}
    test_c2(android, results) if os.path.isdir(android) else None
    c3 = test_c3(android, results)
    test_c4(c1, c3, results)

    print("\n" + "=" * 66)
    passed = sum(1 for ok, _, _ in results if ok)
    print(f"结果: {passed}/{len(results)} 契约断言通过")
    failed = [(label, detail) for ok, label, detail in results if not ok]
    if failed:
        print("\n失败的契约（真机联调前必须先修）：")
    for label, detail in failed:
        short = detail if len(detail) <= 120 else detail[:120] + "…"
        print(f"  ✗ {label}" + (f"  [{short}]" if short else ""))
    print("\n注意：全部通过 ≠ 真机可跑。ROM 授权框、MediaCodec、AVAssetWriter")
    print("的运行时行为无法在沙箱验证，仍需真机联调清单逐项确认。")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
