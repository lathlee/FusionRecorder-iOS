//
//  FusionParams.swift
//  FusionRecorder
//
//  ★ 合成参数的唯一真源（Single Source of Truth）★
//
//  预览（FusionPreview）和录制（VideoPipeline / RecorderSession）必须使用
//  **同一个 FusionParams 实例 + 同一个 FusionCompositor.render**。
//  禁止在任何一处重新解释参数、另写一套滑杆到像素的换算，
//  否则就会出现「预览里调 OK，成片里天差地别」。
//
//  参数语义严格来自交接包
//    01_主项目_FusionRecorder/.../CompositorRenderer.java -> OverlayConfig
//    / FRAGMENT_CAMERA_SHADER / FRAGMENT_SCREEN_SHADER / drawScreenLayer()
//  默认值来自 MainActivity.loadPrefsIntoUi 与 Prefs.apply。
//
//  一致性要点：
//   · 所有几何量归一化到成片画布 canvasWidth×canvasHeight，
//     与预览控件在 iPhone 屏幕上占多少像素完全无关；
//   · 预览渲染尺寸 == 成片分辨率，得到的就是成片里的那一帧，
//     只是被缩小显示；
//   · 采集参数里的「摄像头分辨率 / 画面旋转」也进入合成，
//     所以它们在预览里同样看得见变化。
//

import Foundation

struct FusionParams: Equatable {

    // MARK: - 成片画布（来自「采集参数」）

    /// 输出视频宽（由摄像头分辨率下拉决定）
    var canvasWidth: Int = 1280
    /// 输出视频高
    var canvasHeight: Int = 720
    /// 画面旋转校正角度 0 / 90 / 180 / 270，作用于相机层
    var rotation: Int = 0

    // MARK: - 叠加效果（主界面 10 条滑杆）

    var alpha: Double = 0.55          // 屏幕透明度
    var scale: Double = 0.55           // 屏幕占比（宽度占画布宽）
    var offsetX: Double = 0.0          // 水平位置（单位：画布宽）
    var offsetY: Double = 0.06          // 垂直位置（单位：画布高，正值向上）
    var additive: Double = 0.35       // 发光强度（加色混合比例）
    var corner: Double = 0.10          // 圆角（相对 overlay 短边）
    var edgeFade: Double = 0.12        // 边缘渐隐宽度
    var brightness: Double = 1.0        // 屏幕亮度
    var contrast: Double = 1.0         // 摄像头对比度
    var crop: Double = 0.06            // 裁掉屏幕内容右侧（悬浮球不入镜）

    // MARK: - Android 端固定值（UI 未暴露，但成片里真实生效，必须同步）

    var cameraBrightness: Double = 0.0
    var tintR: Double = 0.98           // 波导片轻微色偏
    var tintG: Double = 1.02
    var tintB: Double = 1.00
    var skewTop: Double = 1.0          // 梯形透视顶边系数
    var skewBottom: Double = 1.0       // 梯形透视底边系数

    // MARK: - 从采集参数下拉推导画布

    /// Options.resolutions 的索引 → 成片分辨率
    static func canvasSize(forResolutionIndex index: Int) -> (width: Int, height: Int) {
        switch index {
        case 0:  return (640, 480)
        case 2:  return (1920, 1080)
        default: return (1280, 720)
        }
    }

    /// Options.rotations 的索引 → 角度
    static func degrees(forRotationIndex index: Int) -> Int {
        switch index {
        case 1:  return 90
        case 2:  return 180
        case 3:  return 270
        default: return 0
        }
    }

    /// 预览渲染尺寸就是成片尺寸；不要按预览控件尺寸缩放画布，
    /// 否则圆角/边缘渐隐/裁切会跟着控件大小漂移。
    var renderSize: (width: Int, height: Int) { (canvasWidth, canvasHeight) }

    /// 用于日志/校验：把所有参数打成一个稳定字符串
    var fingerprint: String {
        let values: [Double] = [alpha, scale, offsetX, offsetY, additive, corner,
                                edgeFade, brightness, contrast, crop,
                                cameraBrightness, tintR, tintG, tintB,
                                skewTop, skewBottom]
        let body = values.map { String(format: "%.4f", $0) }.joined(separator: ",")
        return "\(canvasWidth)x\(canvasHeight)@r\(rotation)[\(body)]"
    }
}
