//
//  FrameStore.swift
//  FusionRecorder
//
//  预览用的**真实帧**来源管理。三路来源，互相替换，选中帧持久化到 Documents：
//
//    A. 内置样例：交接包 02_PoC_双路流/dual_cam.h264 / dual_screen.h264
//       各自解出的真实一帧（不是 SwiftUI 手绘），离线也能立刻看到真实合成效果；
//    B. 从眼镜抓帧：连上眼镜后，9114（屏幕）/ 9115（相机）两路 H264
//       各解一帧，替换掉样例；
//    C. 从相册导入：真机链路未通时，手动挑两张真实截图也能标定参数。
//
//  无论哪一路，最终都交给同一个 FusionCompositor.render，
//  所以「看到的」就是「录下来的」。
//

import Foundation
import CoreGraphics
import UIKit

enum FrameOrigin: String {
    /// 0.5.3 新增：还没有任何真实帧。预览区显示占位，**不再回落到旧帧**。
    case none = "暂无画面"
    case sample = "内置 PoC 真实帧"
    case glasses = "眼镜实时抓帧"
    case photos = "相册导入"
}

final class FrameStore: ObservableObject {

    @Published private(set) var screenImage: CGImage?
    @Published private(set) var cameraImage: CGImage?
    @Published private(set) var origin: FrameOrigin = .none
    @Published private(set) var note: String = "连接眼镜后点「刷新预览」抓一帧真实画面"
    /// 每次换帧 +1，供预览层判断是否需要重新合成
    @Published private(set) var revision: Int = 0

    private let fileManager = FileManager.default

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var screenFile: URL { documentsURL.appendingPathComponent("preview_screen.png") }
    private var cameraFile: URL { documentsURL.appendingPathComponent("preview_camera.png") }

    /// 两张真实帧都到位才算「有画面可显示」。
    var hasFrames: Bool { screenImage != nil && cameraImage != nil }

    /// Documents 里是否还留着上一次抓的两帧（供调试区「恢复上次抓取的两帧」用）
    var hasSavedFrames: Bool {
        fileManager.fileExists(atPath: screenFile.path)
            && fileManager.fileExists(atPath: cameraFile.path)
    }

    init() {
        // ★ 0.5.3：启动时**不再**恢复上次保存的帧，也不再用内置样例兜底。
        // 真机踩过：眼镜连不上时界面照样显示上一次的合成画面，看起来像「连上了」，
        // 于是把问题指向「IP 不对」——其实预览是旧的。没有新帧就老实显示占位。
        // 保存的文件仍然留在 Documents，需要时由用户点「恢复上次抓取的两帧」显式加载。
        screenImage = nil
        cameraImage = nil
        origin = .none
        note = "连接眼镜后点「刷新预览」抓一帧真实画面"
    }

    /// 断开连接 / 部署失败时调用：把预览退回占位，不留旧画面。
    func clear() {
        guard screenImage != nil || cameraImage != nil || origin != .none else { return }
        screenImage = nil
        cameraImage = nil
        origin = .none
        note = "连接眼镜后点「刷新预览」抓一帧真实画面"
        revision += 1
    }

    /// 显式恢复上一次抓/导入的两帧（调试用，不会自动触发）。
    func restoreSaved() {
        guard let s = loadPNG(screenFile), let c = loadPNG(cameraFile) else { return }
        screenImage = s
        cameraImage = c
        origin = .photos
        note = "已恢复上次保存的两张真实帧（调试用，不是当前眼镜画面）"
        revision += 1
    }

    // MARK: - 内置真实帧

    func resetToSample() {
        screenImage = bundleImage("sample_screen")
        cameraImage = bundleImage("sample_camera")
        origin = .sample
        note = "交接包 PoC 双路 H264 解出的真实帧（相机镜头朝下，画面偏暗属正常）"
        revision += 1
        try? fileManager.removeItem(at: screenFile)
        try? fileManager.removeItem(at: cameraFile)
    }

    // MARK: - 从眼镜抓帧（RecorderSession 解出两帧后调用）

    func applyGlassesFrames(screen: CGImage?, camera: CGImage?) {
        guard let s = screen, let c = camera else { return }
        screenImage = s
        cameraImage = c
        origin = .glasses
        note = "9114 屏幕流 / 9115 相机流各解出一帧"
        revision += 1
        savePNG(s, to: screenFile)
        savePNG(c, to: cameraFile)
    }

    // MARK: - 从相册导入

    func applyImported(data: Data, isScreen: Bool) {
        guard let image = UIImage(data: data)?.cgImage else { return }
        if isScreen { screenImage = image } else { cameraImage = image }
        origin = .photos
        note = isScreen ? "屏幕帧来自相册，相机帧为 \(currentCounterpart(isScreen: true))"
                        : "相机帧来自相册，屏幕帧为 \(currentCounterpart(isScreen: false))"
        revision += 1
        savePNG(image, to: isScreen ? screenFile : cameraFile)
    }

    private func currentCounterpart(isScreen: Bool) -> String {
        let other = isScreen ? cameraFile : screenFile
        if fileManager.fileExists(atPath: other.path) {
            return origin == .sample ? "内置 PoC 真实帧" : "上次保存的真实帧"
        }
        return "内置 PoC 真实帧"
    }

    // MARK: - 工具

    private func bundleImage(_ name: String) -> CGImage? {
        if let ui = UIImage(named: name), let cg = ui.cgImage { return cg }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let data = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(pngDataProviderSource: provider, decode: nil,
                      shouldInterpolate: true, intent: .defaultIntent)
    }

    private func loadPNG(_ url: URL) -> CGImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)?.cgImage
    }

    private func savePNG(_ image: CGImage, to url: URL) {
        let ui = UIImage(cgImage: image)
        guard let data = ui.pngData() else { return }
        try? data.write(to: url, options: .atomic)
    }
}
