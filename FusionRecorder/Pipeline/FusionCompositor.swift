//
//  FusionCompositor.swift
//  FusionRecorder
//
//  ★ 唯一合成实现 ★
//
//  预览和录制都只准调用 render(screen:camera:params:)。这个函数是交接包
//  CompositorRenderer.java 的两个 GLSL shader + drawScreenLayer() 的逐像素复刻：
//
//    相机层  rgb = (rgb - 0.5) * contrast + 0.5 + camBrightness
//    屏幕层  rgb = texel * tint * brightness
//            mask = roundedBoxMask(vLocal, overlayAspect, corner)
//            edge = 1 - smoothstep(1 - edgeFade, 1, max(|vLocal-0.5|*2))
//            a    = alpha * mask * edge
//            add  = rgb * a * additive
//            src  = vec4(rgb*a + add*0.6, a + |add|*0.35)     // 预乘
//    混合    GL_ONE / GL_ONE_MINUS_SRC_ALPHA
//
//  与 tools/render_preview.py 逐行等价，可用该脚本离线核对成片里的这一帧。
//
//  ⚠️ 一致性约定（改代码前先读）：
//   1. 画布尺寸取 params.renderSize，即成片分辨率；预览控件多大都不影响画布；
//   2. 所有位置/大小都是相对画布宽高的归一化量，没有 0.92 / 60px 这类魔法数；
//   3. 预览渲染出的 CGImage 就是成片写帧时用的那张图，没有第二套路径。
//

import Foundation
import Darwin
import CoreGraphics
import UIKit

enum FusionCompositor {

    // BGRA8、alpha 置 255。rasterize / 输出都用同一约定，避免上下/通道翻转。
    private static let bitmapInfo: UInt32 =
        CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue

    // MARK: - 唯一入口

    /// 把一帧眼镜屏幕画面与一帧摄像头画面合成为成片里的一帧。
    /// - Parameters:
    ///   - screen: 眼镜屏幕流的一帧（真实截图 / H264 解码帧）
    ///   - camera: 摄像头流的一帧（真实截图 / H264 解码帧）
    ///   - params: 预览与录制共用的同一份参数
    /// - Returns: 尺寸恒为 params.renderSize 的合成帧
    static func render(screen: CGImage, camera: CGImage, params: FusionParams) -> CGImage? {
        let W = params.canvasWidth
        let H = params.canvasHeight
        guard W > 0, H > 0, screen.width > 0, screen.height > 0, camera.width > 0, camera.height > 0 else {
            return nil
        }

        // ---- 相机层：铺满画布 -------------------------------------------------
        guard var cam = rasterize(camera, width: W, height: H,
                                  rotation: params.rotation, aspectFill: true) else { return nil }
        // contrast=1 且 brightness=0 时是恒等变换，整幅画布逐像素浮点循环纯属浪费
        // （真机实测这是卡顿主因之一）。默认参数直接跳过。
        if abs(Float(params.contrast) - 1.0) > 0.001 || abs(Float(params.cameraBrightness)) > 0.001 {
            applyCameraAdjustment(&cam, width: W, height: H,
                                  contrast: Float(params.contrast),
                                  brightness: Float(params.cameraBrightness))
        }

        // ---- 屏幕层：rasterize 原图，采样时按 uTexMatrix 取左侧 (1-crop) ------
        let sw = screen.width, sh = screen.height
        guard let scr = rasterize(screen, width: sw, height: sh,
                                   rotation: 0, aspectFill: false) else { return nil }

        let crop = min(max(params.crop, 0.0), 0.4)
        let screenAspect = Double(sw) / Double(sh)
        let overlayPhysW = params.scale * Double(W)
        let overlayPhysH = overlayPhysW / screenAspect
        let overlayW = max(1, Int((overlayPhysW * (1.0 - crop)).rounded()))
        let overlayH = max(1, Int(overlayPhysH.rounded()))

        // Android drawScreenLayer()：translate(offsetX*2 + shiftX, offsetY*2)
        // NDC y 向上为正；这里 y 一律「顶边起算」，故 offsetY 正值 = 上移。
        let centerX = Double(W) / 2.0 + params.offsetX * Double(W) - overlayPhysW * crop / 2.0
        let centerY = Double(H) / 2.0 - params.offsetY * Double(H)
        let left = Int((centerX - Double(overlayW) / 2.0).rounded())
        let top  = Int((centerY - Double(overlayH) / 2.0).rounded())

        let fAlpha = Float(params.alpha)
        let fAdditive = Float(params.additive)
        let fBrightness = Float(params.brightness)
        let fCorner = Float(params.corner)
        let fEdgeFade = Float(params.edgeFade)
        let fSkewTop = Float(params.skewTop)
        let fSkewBottom = Float(params.skewBottom)
        let fTintR = Float(params.tintR), fTintG = Float(params.tintG), fTintB = Float(params.tintB)
        let fCrop = Float(crop)

        // roundedBoxMask 里的 overlayAspect（用未裁切的 overlayPhysW/H）
        let maxPhys = max(overlayPhysW, overlayPhysH)
        let aspectX = Float(maxPhys / overlayPhysW)
        let aspectY = Float(maxPhys / overlayPhysH)
        let halfX = 0.5 * aspectX, halfY = 0.5 * aspectY
        let radius = fCorner * min(aspectX, aspectY)

        let fOW = Float(overlayW), fOH = Float(overlayH)
        let fSW = Float(sw), fSH = Float(sh)
        let yStart = max(0, top), yEnd = min(H, top + overlayH)
        let xStart = max(0, left), xEnd = min(W, left + overlayW)

        cam.withUnsafeMutableBufferPointer { dst in
            scr.withUnsafeBufferPointer { src in
                for y in stride(from: yStart, to: max(yStart, yEnd), by: 1) {
                    let v = (Float(y - top) + 0.5) / fOH         // 0 = 面板顶边
                    // 顶点着色器：t = (y_ndc+1)/2，顶边 1 → skewTop
                    let t = 1.0 - v
                    let skew = fSkewBottom + (fSkewTop - fSkewBottom) * t
                    let dstRow = (H - 1 - y) * W * 4         // CG 位图行 0 = 画面底部

                    for x in stride(from: xStart, to: max(xStart, xEnd), by: 1) {
                        let u = (Float(x - left) + 0.5) / fOW
                        // 梯形透视：把物理 x 反解回 quad 参数坐标，并判内外
                        let halfSpan = 0.5 * skew
                        let du = u - 0.5
                        guard abs(du) <= halfSpan else { continue }
                        let uQuad = skew == 0 ? u : min(max(0.5 + du / skew, 0.0), 1.0)

                        // roundedBoxMask
                        let px = (uQuad - 0.5) * aspectX
                        let py = (v - 0.5) * aspectY
                        let qx = abs(px) - halfX + radius
                        let qy = abs(py) - halfY + radius
                        let d = min(max(qx, qy), 0.0) + sqrtf(max(qx, 0) * max(qx, 0) + max(qy, 0) * max(qy, 0)) - radius
                        let mask = 1.0 - smoothstep(-0.004, 0.004, d)

                        // 边缘渐隐
                        let e = max(abs(uQuad - 0.5) * 2.0, abs(v - 0.5) * 2.0)
                        let edge = 1.0 - smoothstep(1.0 - fEdgeFade, 1.0, e)

                        let a = min(max(fAlpha * mask * edge, 0.0), 1.0)
                        if a <= 0.0001 { continue }

                        // 采样屏幕帧：vTexCoord.x = vLocal.x * (1-crop)
                        let sxf = min(max(uQuad * (1.0 - fCrop) * fSW, 0.0), fSW - 1)
                        let syf = min(max(v * fSH, 0.0), fSH - 1)
                        let sxp = Int(sxf)
                        let syp = Int(syf)
                        let srcRow = (sh - 1 - syp) * sw * 4
                        let si = srcRow + sxp * 4
                        let sB = Float(src[si]) / 255.0
                        let sG = Float(src[si + 1]) / 255.0
                        let sR = Float(src[si + 2]) / 255.0

                        var r = min(max(sR * fTintR * fBrightness, 0.0), 1.0)
                        var g = min(max(sG * fTintG * fBrightness, 0.0), 1.0)
                        var b = min(max(sB * fTintB * fBrightness, 0.0), 1.0)

                        let addR = r * a * fAdditive
                        let addG = g * a * fAdditive
                        let addB = b * a * fAdditive
                        let srcR = r * a + addR * 0.6
                        let srcG = g * a + addG * 0.6
                        let srcB = b * a + addB * 0.6
                        let srcA = min(max(a + sqrtf(addR * addR + addG * addG + addB * addB) * 0.35, 0.0), 1.0)

                        let di = dstRow + x * 4
                        let keep = 1.0 - srcA
                        r = min(max(srcR + (Float(dst[di + 2]) / 255.0) * keep, 0.0), 1.0)
                        g = min(max(srcG + (Float(dst[di + 1]) / 255.0) * keep, 0.0), 1.0)
                        b = min(max(srcB + (Float(dst[di]) / 255.0) * keep, 0.0), 1.0)
                        dst[di]     = UInt8(b * 255.0 + 0.5)
                        dst[di + 1] = UInt8(g * 255.0 + 0.5)
                        dst[di + 2] = UInt8(r * 255.0 + 0.5)
                        dst[di + 3] = 255
                    }
                }
            }
        }

        return makeImage(from: cam, width: W, height: H)
    }

    // MARK: - 私有

    @inline(__always)
    private static func smoothstep(_ a: Float, _ b: Float, _ x: Float) -> Float {
        let t = min(max((x - a) / (b - a + 1e-9), 0.0), 1.0)
        return t * t * (3.0 - 2.0 * t)
    }

    /// 相机层 contrast / brightness（全图一遍，独立于 overlay）
    private static func applyCameraAdjustment(_ buf: inout [UInt8], width: Int, height: Int,
                                              contrast: Float, brightness: Float) {
        buf.withUnsafeMutableBufferPointer { p in
            for i in stride(from: 0, to: width * height * 4, by: 4) {
                let b = min(max((Float(p[i]) / 255.0 - 0.5) * contrast + 0.5 + brightness, 0.0), 1.0)
                let g = min(max((Float(p[i + 1]) / 255.0 - 0.5) * contrast + 0.5 + brightness, 0.0), 1.0)
                let r = min(max((Float(p[i + 2]) / 255.0 - 0.5) * contrast + 0.5 + brightness, 0.0), 1.0)
                p[i] = UInt8(b * 255.0 + 0.5)
                p[i + 1] = UInt8(g * 255.0 + 0.5)
                p[i + 2] = UInt8(r * 255.0 + 0.5)
                p[i + 3] = 255
            }
        }
    }

    /// 把任意 CGImage 重采样成 BGRA8 buffer（行 0 = 画面底部，与 CGContext 一致）
    private static func rasterize(_ image: CGImage, width: Int, height: Int,
                                  rotation: Int, aspectFill: Bool) -> [UInt8]? {
        var buf = [UInt8](repeating: 0, count: width * height * 4)
        let ok = buf.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(data: raw.baseAddress,
                                      width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: bitmapInfo) else { return false }
            ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.interpolationQuality = .high
            ctx.saveGState()
            if rotation != 0 {
                ctx.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
                ctx.rotate(by: CGFloat(rotation) * .pi / 180.0)
                ctx.translateBy(x: -CGFloat(width) / 2, y: -CGFloat(height) / 2)
            }
            let sw = CGFloat(image.width), sh = CGFloat(image.height)
            let rect: CGRect
            if aspectFill {
                let s = max(CGFloat(width) / sw, CGFloat(height) / sh)
                let dw = sw * s, dh = sh * s
                rect = CGRect(x: (CGFloat(width) - dw) / 2, y: (CGFloat(height) - dh) / 2,
                              width: dw, height: dh)
            } else {
                rect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
            }
            ctx.draw(image, in: rect)
            ctx.restoreGState()
            return true
        }
        return ok ? buf : nil
    }

    private static func makeImage(from bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        var mutable = bytes
        return mutable.withUnsafeMutableBytes { raw -> CGImage? in
            guard let ctx = CGContext(data: raw.baseAddress,
                                      width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: bitmapInfo) else { return nil }
            return ctx.makeImage()
        }
    }
}
