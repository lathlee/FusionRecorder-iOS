#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
v0.2 离线成片基准：用交接包两段真实 H264 跑通「pts 对齐 → CFR 补帧 → 合成 → 成片」全链路。

背景：
  交接包 dual_screen.h264 / dual_cam.h264 是老 PoC 录的**裸流，没有 pts**
  （ffprobe best_effort_timestamp_time = N/A）。这正是 §7 待办 1 要解决的问题。
  本脚本给两路帧补上模拟 pts（屏幕 87 帧 / 相机 97 帧，帧数不同 → 按帧号对齐必错），
  然后走与 iOS v0.2 相同的算法：按 pts 升序取「不晚于目标时刻的最后一帧」补 CFR，
  再用 render_preview.render()（与 FusionCompositor.swift 逐行等价）合成每一帧。

产出：
  preview/v0.2_离线基准.mp4   —— v0.2 真机成片的逐帧比对基准
  preview/v0.2_基准清单.json  —— 每帧取了哪一路的第几帧、对应 pts

用法：
  python3 tools/build_offline_baseline.py [--fps 20] [--seconds 10]
  python3 tools/build_offline_baseline.py --keep-frames   # 保留解出的 PNG 帧，便于排查

注意：这是**近似基准**，因为老样本没有真实 pts。v0.2 采集端已插 SEI pts，
真机录制后把两路带 pts 的流喂进来即可生成精确基准（脚本的 pts 来源留了接口）。
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from render_preview import DEFAULT, render  # noqa: E402

HANDOFF = "/root/.codebuddy/artifact/2f8a7d30-9c21-4f0b-1d72-9d30971fa000/handoff/extracted/FusionRecorder_融合录屏_交接包/02_PoC_双路流"
SCREEN_H264 = os.path.join(HANDOFF, "dual_screen.h264")
CAM_H264 = os.path.join(HANDOFF, "dual_cam.h264")
OUT = os.path.join(ROOT, "preview")


def pick_ffmpeg():
    """优先用带 libx264 的 ffmpeg（交接包也是这么探测的）。"""
    candidates = ["ffmpeg"]
    try:
        import imageio_ffmpeg
        candidates.insert(0, imageio_ffmpeg.get_ffmpeg_exe())
    except Exception:
        pass
    for exe in candidates:
        try:
            r = subprocess.run([exe, "-hide_banner", "-encoders"],
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True)
            if "libx264" in r.stdout:
                return exe
        except Exception:
            continue
    return "ffmpeg"


FFMPEG = pick_ffmpeg()


def run(cmd, **kw):
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                       text=True, **kw)
    if r.returncode != 0:
        print("FAILED:", " ".join(str(c) for c in cmd[:6]))
        print(r.stderr[-2000:])
        sys.exit(r.returncode)
    return r


def extract_frames(h264, outdir, prefix):
    """ffmpeg 解裸 H264 成 PNG 帧序列（按解码/显示顺序）。"""
    os.makedirs(outdir, exist_ok=True)
    pat = os.path.join(outdir, prefix + "_%05d.png")
    run([FFMPEG, "-y", "-v", "error", "-i", h264,
         "-vsync", "0", "-f", "image2", pat])
    frames = sorted(
        os.path.join(outdir, f) for f in os.listdir(outdir)
        if f.startswith(prefix + "_") and f.endswith(".png")
    )
    return frames


def synthesize_pts(count, seconds, kind):
    """
    老样本无 pts，按帧数/时长生成模拟单调时钟时间戳（微秒）。
    两路帧数不同 → 帧号不对应；这正是「按帧号对齐必错」的实证。
    相机流加一个固定的启动偏移，模拟两路采集起点不同（更贴近真机）。
    """
    if count <= 0:
        return []
    start_us = 0 if kind == "screen" else 120_000  # 相机晚 120ms 启动
    step_us = seconds * 1_000_000.0 / count
    return [int(start_us + i * step_us) for i in range(count)]


def anchor_index(pts_list, target_us):
    """
    与 iOS v0.2 / PROTOCOL.md §6 一致的锚点：pts 不晚于 target 的最后一帧。
    返回 (index, pts)；没有更早帧时返回第一帧。
    """
    if not pts_list:
        return None, None
    idx = 0
    for i, t in enumerate(pts_list):
        if t <= target_us:
            idx = i
        else:
            break
    return idx, pts_list[idx]


def label_font(size):
    for path in ("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if os.path.isfile(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                pass
    return ImageFont.load_default()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fps", type=int, default=20, help="CFR 输出帧率")
    ap.add_argument("--seconds", type=float, default=10.0, help="成片时长")
    ap.add_argument("--keep-frames", action="store_true")
    args = ap.parse_args()

    tmp = tempfile.mkdtemp(prefix="fusion_baseline_")
    print("工作目录:", tmp)
    print("解帧中（两段真实 H264）...")
    screen_frames = extract_frames(SCREEN_H264, tmp, "screen")
    cam_frames = extract_frames(CAM_H264, tmp, "cam")
    print("屏幕 %d 帧 / 相机 %d 帧（帧数不同 → 按帧号对齐会错）"
          % (len(screen_frames), len(cam_frames)))
    if not screen_frames or not cam_frames:
        print("解帧失败")
        sys.exit(1)

    s_pts = synthesize_pts(len(screen_frames), args.seconds, "screen")
    c_pts = synthesize_pts(len(cam_frames), args.seconds, "camera")
    print("pts 范围: 屏幕 %d..%d us / 相机 %d..%d us"
          % (s_pts[0], s_pts[-1], c_pts[0], c_pts[-1]))

    os.makedirs(OUT, exist_ok=True)
    work = os.path.join(tmp, "composed")
    os.makedirs(work, exist_ok=True)

    p = dict(DEFAULT)
    total = int(args.fps * args.seconds)
    manifest = []
    print("按 pts 对齐 + CFR 补帧 + 合成 %d 帧..." % total)
    for k in range(total):
        t_us = int(k * 1_000_000.0 / args.fps)
        si, s_at = anchor_index(s_pts, t_us)
        ci, c_at = anchor_index(c_pts, t_us)
        img = render(screen_frames[si], cam_frames[ci], p)
        outp = os.path.join(work, "f_%05d.png" % k)
        img.save(outp)
        manifest.append(dict(outFrame=k, tUs=t_us,
                             screenFrame=si, screenPtsUs=s_at,
                             camFrame=ci, camPtsUs=c_at))
        if (k + 1) % 40 == 0:
            print("  %d/%d" % (k + 1, total), flush=True)

    mp4 = os.path.join(OUT, "v0.2_离线基准.mp4")
    run([FFMPEG, "-y", "-v", "error",
         "-framerate", str(args.fps), "-i", os.path.join(work, "f_%05d.png"),
         "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18",
         "-movflags", "+faststart", mp4])
    mpath = os.path.join(OUT, "v0.2_基准清单.json")
    with open(mpath, "w", encoding="utf-8") as f:
        json.dump(dict(fps=args.fps, seconds=args.seconds,
                       screenFrameCount=len(screen_frames),
                       camFrameCount=len(cam_frames),
                       note="老样本无真实 pts；此处按帧数/时长生成模拟时间戳",
                       frames=manifest), f, ensure_ascii=False, indent=1)

    # 首帧拼一个对照标签，便于快速目视核对
    first = Image.open(os.path.join(work, "f_00000.png")).convert("RGB")
    thumb = first.resize((640, 360), Image.LANCZOS)
    sheet = Image.new("RGB", (640, 400), (18, 18, 18))
    d = ImageDraw.Draw(sheet)
    d.text((12, 8), "v0.2 离线基准首帧（两路真实帧 + pts 对齐合成）",
           fill=(224, 224, 224), font=label_font(15))
    sheet.paste(thumb, (0, 40))
    png = os.path.join(OUT, "v0.2_离线基准_首帧.png")
    sheet.save(png)

    print("\n完成：")
    print("  ", mp4)
    print("  ", mpath)
    print("  ", png)
    # 验证不同步：统计两路锚点帧号差的最大值
    max_gap = max(abs(m["screenFrame"] - m["camFrame"]
                      * len(screen_frames) / len(cam_frames)) for m in manifest)
    print("  帧号/时间轴最大偏差: %.1f 帧（证明必须按 pts 而不能按帧号对齐）" % max_gap)

    if args.keep_frames:
        keep = os.path.join(OUT, "baseline_frames")
        if os.path.isdir(keep):
            shutil.rmtree(keep)
        shutil.copytree(work, keep)
        print("  已保留解帧:", keep)
    else:
        shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
