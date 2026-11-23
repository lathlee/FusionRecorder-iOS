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

    var alpha: Double = 0.60          // 屏幕透明度
    var scale: Double = 0.75           // 屏幕占比（宽度占画布宽）
    var offsetX: Double = 0.0          // 水平位置（单位：画布宽）
    var offsetY: Double = 0.06          // 垂直位置（单位：画布高，正值向上）
    var additive: Double = 0.35       // 发光强度（加色混合比例）
    var corner: Double = 0.04          // 圆角（相对 overlay 短边）
    var edgeFade: Double = 0.0         // 边缘渐隐宽度
    var brightness: Double = 1.0        // 屏幕亮度
    var contrast: Double = 0.75        // 摄像头对比度
    var crop: Double = 0.0             // 裁掉屏幕内容右侧（悬浮球不入镜）

    // MARK: - 去黑底（0.6.2）

    /// 0 = 关闭（原来的整体混色）；1 = 亮度键；2 = 滤色。
    ///
    /// 为什么需要它：`screencap` 拿到的是**不透明** RGBA，黑背景就是实实在在的
    /// 黑色像素。而波导眼镜在光学上「黑 = 不发光 = 透明」，所以肉眼透过镜片
    /// 看不到黑底，录成数字视频却会留一块黑矩形。要还原那个光学特性，
    /// 就得用亮度键 / 滤色把「黑」当成「无」。
    var keyMode: Int = 0
    /// 亮度低于它 → 完全透明（亮度键）
    var keyThreshold: Double = 0.06
    /// 阈值附近的过渡宽度，避免边缘发硬
    var keySoftness: Double = 0.06
    /// 内容增益：背景换成相机画面后对比度会下降，用它把内容提亮一点
    var keyGain: Double = 1.0

    // MARK: - 声音（0.5.0）

    /// 成片音量倍数。1.0 = 原始音量；>1 放大，<1 衰减。
    /// 只作用于**之后**合成的新成片（已经存进相册的文件不会被改动），
    /// 实现方式是 AVMutableAudioMix 的 setVolume，不重新编码音轨。
    var audioVolume: Double = 1.0

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

    /// 用于日志/校验：把所有**影响画面**的参数打成一个稳定字符串。
    /// 注意：`audioVolume` 故意不进 fingerprint —— 预览只渲染画面，
    /// 拖音量滑杆不该触发上千帧的重新合成。
    var fingerprint: String {
        let values: [Double] = [alpha, scale, offsetX, offsetY, additive, corner,
                                edgeFade, brightness, contrast, crop,
                                cameraBrightness, tintR, tintG, tintB,
                                skewTop, skewBottom,
                                Double(keyMode), keyThreshold, keySoftness, keyGain]
        let body = values.map { String(format: "%.4f", $0) }.joined(separator: ",")
        return "\(canvasWidth)x\(canvasHeight)@r\(rotation)[\(body)]"
    }
}
