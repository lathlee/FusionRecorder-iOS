#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FusionRecorder 预览/成片合成算法的**参考实现**（与 iOS 端 FusionCompositor.swift 逐行等价）。

用途：
  1. 在没有 Xcode / 没连眼镜时，用交接包 PoC 双路 H264 解出的真实帧离线合成效果图；
  2. 作为「预览效果 == 最终成片效果」的第三方核对工具：改动任何一端参数，
     用本脚本重算即可得到成片里那一帧的样子。

算法来源（严格复刻，不做任何「看起来更顺眼」的魔改）：
  01_主项目_FusionRecorder/.../CompositorRenderer.java
    · FRAGMENT_CAMERA_SHADER   (rgb-0.5)*contrast + 0.5 + camBrightness
    · FRAGMENT_SCREEN_SHADER  tint / brightness / roundedBoxMask / edgeFade /
                               additive / 预乘 alpha 输出
    · drawScreenLayer()       scale / offsetX / offsetY / cropRight 的 NDC 几何
    · GL_ONE / GL_ONE_MINUS_SRC_ALPHA 混合

所有几何量都归一化到「成片画布」 W×H，与预览控件在屏幕上有多少像素**无关**。
这就是为什么预览里调好的参数，成片里不会变样。

用法：
  python3 tools/render_preview.py                      # 生成默认参数效果图
  python3 tools/render_preview.py --compare            # 额外生成参数变化三联对照
"""

import argparse
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "FusionRecorder", "Resources")
OUT = os.path.join(ROOT, "preview")

# 与 Android OverlayConfig / MainActivity 默认值一致
DEFAULT = dict(
    canvasW=1280, canvasH=720,     # 「摄像头分辨率」决定输出视频分辨率
    scale=0.55, offsetX=0.0, offsetY=0.06,
    alpha=0.55, additive=0.35, corner=0.10, edgeFade=0.12,
    brightness=1.0, contrast=1.0, crop=0.06,
    camBrightness=0.0,
    tint=(0.98, 1.02, 1.00),      # 波导片轻微色偏，Android 固定值
    skewTop=1.0, skewBottom=1.0, # 梯形透视，默认无透视
    rotation=0,
)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a + 1e-9), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def aspect_fill(im, w, h, rotation=0):
    """把源图铺满 w×h 画布（居中裁切），并先做画面旋转校正。"""
    if rotation:
        im = im.rotate(rotation, expand=True)
    sw, sh = im.size
    s = max(w / sw, h / sh)
    nw, nh = max(1, round(sw * s)), max(1, round(sh * s))
    im = im.resize((nw, nh), Image.LANCZOS)
    left, top = (nw - w) // 2, (nh - h) // 2
    return np.asarray(im.crop((left, top, left + w, top + h)).convert("RGB"), dtype=np.float32) / 255.0


def render(screen_path, camera_path, p):
    """唯一合成入口。iOS 端 FusionCompositor.render 与本函数等价。"""
    W, H = p["canvasW"], p["canvasH"]

    # --- 相机层：铺满画布 + contrast / brightness -------------------------
    cam = aspect_fill(Image.open(camera_path), W, H, p["rotation"])
    cam = np.clip((cam - 0.5) * p["contrast"] + 0.5 + p["camBrightness"], 0.0, 1.0)

    # --- 屏幕层几何（全部相对 W/H 归一化）--------------------------------
    scr = Image.open(screen_path).convert("RGB")
    sw, sh = scr.size
    screen_aspect = sw / float(sh) if sh else 16.0 / 9.0

    crop = min(max(p["crop"], 0.0), 0.4)
    overlay_phys_w = p["scale"] * W                       # 未裁切时的宽度
    overlay_phys_h = overlay_phys_w / screen_aspect
    overlay_w = overlay_phys_w * (1.0 - crop)              # 裁掉右侧后变窄
    overlay_h = overlay_phys_h

    # Android：translate(offsetX*2 + shiftX, offsetY*2)，shiftX = -ndcW*crop/2
    # NDC y 向上为正 → 图像坐标 y 向下，所以 center_y = H/2 - offsetY*H
    center_x = W / 2.0 + p["offsetX"] * W - overlay_phys_w * crop / 2.0
    center_y = H / 2.0 - p["offsetY"] * H

    ow, oh = max(1, int(round(overlay_w))), max(1, int(round(overlay_h)))
    left, top = int(round(center_x - ow / 2.0)), int(round(center_y - oh / 2.0))

    # 纹理只取左边 (1-crop)，再缩到 overlay 尺寸：等价于 shader 的 uTexMatrix
    cropped = scr.crop((0, 0, max(1, int(sw * (1.0 - crop))), sh))
    panel = np.asarray(cropped.resize((ow, oh), Image.LANCZOS), dtype=np.float32) / 255.0

    tint = np.array(p["tint"], dtype=np.float32)
    panel = np.clip(panel * tint * p["brightness"], 0.0, 1.0)

    # roundedBoxMask / edgeFade 在 vLocal(0..1) 空间计算，与控件像素无关
    ov_aspect = (max(overlay_phys_w, overlay_phys_h) / overlay_phys_w,
                 max(overlay_phys_w, overlay_phys_h) / overlay_phys_h)
    vy, vx = np.mgrid[0:oh, 0:ow].astype(np.float32)
    u = (vx + 0.5) / ow
    v = (vy + 0.5) / oh

    px = (u - 0.5) * ov_aspect[0]
    py = (v - 0.5) * ov_aspect[1]
    half_x, half_y = 0.5 * ov_aspect[0], 0.5 * ov_aspect[1]
    r = p["corner"] * min(ov_aspect[0], ov_aspect[1])
    qx, qy = np.abs(px) - half_x + r, np.abs(py) - half_y + r
    d = np.minimum(np.maximum(qx, qy), 0.0) + np.hypot(np.maximum(qx, 0.0), np.maximum(qy, 0.0)) - r
    mask = 1.0 - smoothstep(-0.004, 0.004, d)

    e = np.maximum(np.abs(u - 0.5) * 2.0, np.abs(v - 0.5) * 2.0)
    edge = 1.0 - smoothstep(1.0 - p["edgeFade"], 1.0, e)

    a = np.clip(p["alpha"] * mask * edge, 0.0, 1.0)
    add = panel * a[..., None] * p["additive"]
    src_rgb = panel * a[..., None] + add * 0.6
    src_a = np.clip(a + np.linalg.norm(add, axis=2) * 0.35, 0.0, 1.0)

    # --- 合成：GL_ONE / GL_ONE_MINUS_SRC_ALPHA（src 已是预乘）--------------
    x0, y0 = max(0, left), max(0, top)
    x1, y1 = min(W, left + ow), min(H, top + oh)
    out = cam.copy()
    if x1 > x0 and y1 > y0:
        px0, py0 = x0 - left, y0 - top
        pw, ph = x1 - x0, y1 - y0
        dst = out[y0:y1, x0:x1]
        srgb = src_rgb[py0:py0 + ph, px0:px0 + pw]
        sa = src_a[py0:py0 + ph, px0:px0 + pw, None]
        out[y0:y1, x0:x1] = np.clip(srgb + dst * (1.0 - sa), 0.0, 1.0)

    return Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), "RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compare", action="store_true", help="额外生成参数变化三联对照")
    ap.add_argument("--alpha", type=float)
    ap.add_argument("--scale", type=float)
    ap.add_argument("--offset-x", type=float)
    ap.add_argument("--offset-y", type=float)
    args = ap.parse_args()

    os.makedirs(OUT, exist_ok=True)
    cam = os.path.join(RES, "sample_camera.png")
    scr = os.path.join(RES, "sample_screen.png")
    for f in (cam, scr):
        if not os.path.isfile(f):
            print("缺少真实帧资源:", f)
            sys.exit(1)

    p = dict(DEFAULT)
    for k, v in (("alpha", args.alpha), ("scale", args.scale),
                 ("offsetX", args.offset_x), ("offsetY", args.offset_y)):
        if v is not None:
            p[k] = v

    out = render(scr, cam, p)
    path = os.path.join(OUT, "融合预览_真实帧_v0.1.2.png")
    out.save(path)
    print("已生成:", path, out.size)

    if args.compare:
        from PIL import ImageDraw, ImageFont

        def label_font(size):
            for path in ("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
                         "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
                if os.path.isfile(path):
                    try:
                        return ImageFont.truetype(path, size)
                    except OSError:
                        pass
            return ImageFont.load_default()

        cases = [
            ("默认参数（透明度 0.55 / 占比 0.55）", dict(p)),
            ("透明度 0.20（更透）", dict(p, alpha=0.20)),
            ("占比 0.80 + 右移 0.12 + 透明度 0.85", dict(p, scale=0.80, offsetX=0.12, alpha=0.85)),
            ("圆角 0.35 / 渐隐 0.35 / 对比度 1.4", dict(p, corner=0.35, edgeFade=0.35, contrast=1.4)),
        ]
        tw, th, head = 640, 360, 30
        sheet = Image.new("RGB", (tw * 2, (th + head) * 2), (18, 18, 18))
        draw = ImageDraw.Draw(sheet)
        font = label_font(15)
        for i, (label, cfg) in enumerate(cases):
            tile = render(scr, cam, cfg).resize((tw, th), Image.LANCZOS)
            x, y = (i % 2) * tw, (i // 2) * (th + head)
            draw.text((x + 10, y + 6), label, fill=(224, 224, 224), font=font)
            sheet.paste(tile, (x, y + head))
        cp = os.path.join(OUT, "参数实时变化_四宫格.png")
        sheet.save(cp)
        print("已生成:", cp, sheet.size)


if __name__ == "__main__":
    main()
