//
//  RecorderSession.swift
//  FusionRecorder
//
//  把 ADB + 双路流 + 唯一合成器串起来，并给 SwiftUI 提供状态。
//
//  ★ 预览 / 抓帧 / 录制 三条路径都指向同一个 FusionCompositor：
//    · 预览：FrameStore 的两张真实帧 → FusionCompositor（FusionPreview 负责显示）
//    · 抓帧：9114 / 9115 各解一帧 → 存进 FrameStore → 立刻成为新的预览源
//    · 录制：双路实时帧 → RecordingCompositor（内部同样调 FusionCompositor）
//  参数统一由 ContentView 组装成 FusionParams 后 update 进来，不存在两套数值。
//

import Foundation
import Combine
import CoreGraphics

final class RecorderSession: ObservableObject {

    @Published private(set) var isRunning = false
    @Published private(set) var log: [String] = []
    @Published private(set) var screenNALCount = 0
    @Published private(set) var cameraNALCount = 0
    /// 录制中的实时合成帧（就是成片里正在写的那一帧，只是缩小显示）
    @Published private(set) var livePreview: CGImage?
    @Published private(set) var captureState = "未抓帧"
    @Published private(set) var captureInProgress = false

    /// 抓到的真实帧交给它保存，随后自动成为预览源
    weak var frameStore: FrameStore?

    private let recordingCompositor = RecordingCompositor(params: FusionParams())
    private var screenDecoder = H264FrameDecoder()
    private var cameraDecoder = H264FrameDecoder()

    private var adb: ADBClient?
    private var screenReceiver: H264StreamReceiver?
    private var cameraReceiver: H264StreamReceiver?

    private var captureScreenReceiver: H264StreamReceiver?
    private var captureCameraReceiver: H264StreamReceiver?
    private var captureScreenDecoder = H264FrameDecoder()
    private var captureCameraDecoder = H264FrameDecoder()

    private let frameLock = NSLock()
    private var liveScreen: CGImage?
    private var liveCamera: CGImage?
    private var capturedScreen: CGImage?
    private var capturedCamera: CGImage?
    private var lastComposeAt: TimeInterval = 0

    /// UI 在每次参数变化时调用，保证录制用的就是预览里那组数值
    func update(params: FusionParams) {
        recordingCompositor.update(params)
    }

    var params: FusionParams { recordingCompositor.currentParams }

    // MARK: - 录制

    func start(host: String, screenPort: UInt16, cameraPort: UInt16) {
        guard !isRunning else { return }
        isRunning = true
        livePreview = nil
        append("启动：ADB \(host):5555 / 屏幕 \(screenPort) / 相机 \(cameraPort)")
        append("合成参数：\(params.fingerprint)")

        let client = ADBClient(host: host, port: 5555)
        client.log = { [weak self] message in self?.append("[ADB] \(message)") }
        adb = client
        client.connect { [weak self] result in
            switch result {
            case .success: self?.append("ADB 握手完成")
            case .failure(let error): self?.append("ADB 连接失败：\(error.localizedDescription)")
            }
        }

        screenDecoder = H264FrameDecoder()
        cameraDecoder = H264FrameDecoder()
        let screen = H264StreamReceiver(host: host, port: screenPort, label: "screen",
            onNAL: { [weak self] nal in
                self?.bumpScreen()
                self?.handleLive(nal, isScreen: true)
            },
            onState: { [weak self] message in self?.append("[屏幕] \(message)") })
        let camera = H264StreamReceiver(host: host, port: cameraPort, label: "camera",
            onNAL: { [weak self] nal in
                self?.bumpCamera()
                self?.handleLive(nal, isScreen: false)
            },
            onState: { [weak self] message in self?.append("[相机] \(message)") })

        screenReceiver = screen
        cameraReceiver = camera
        screen.start()
        camera.start()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        screenReceiver?.stop()
        cameraReceiver?.stop()
        adb?.disconnect()
        screenDecoder.invalidate()
        cameraDecoder.invalidate()
        frameLock.lock()
        liveScreen = nil
        liveCamera = nil
        frameLock.unlock()
        append("已停止（合成帧已按预览参数生成；逐帧编码写相册待 v0.2）")
    }

    /// 双路各来一帧就合成一次（做节流，CPU 逐像素合成不追赶 30fps）
    private func handleLive(_ nal: Data, isScreen: Bool) {
        let decoder = isScreen ? screenDecoder : cameraDecoder
        guard let frame = decoder.feed(nal) else { return }

        frameLock.lock()
        if isScreen { liveScreen = frame } else { liveCamera = frame }
        let s = liveScreen
        let c = liveCamera
        let now = Date().timeIntervalSince1970
        let shouldCompose = (s != nil && c != nil && now - lastComposeAt > 0.12)
        if shouldCompose { lastComposeAt = now }
        frameLock.unlock()

        guard shouldCompose, let s = s, let c = c else { return }
        let composed = recordingCompositor.compose(screen: s, camera: c)
        DispatchQueue.main.async { [weak self] in
            self?.livePreview = composed
        }
    }

    // MARK: - 从眼镜抓两帧（用户要求的真实预览源）

    func captureFrames(host: String, screenPort: UInt16, cameraPort: UInt16) {
        guard !captureInProgress else { return }
        captureInProgress = true
        captureState = "正在连接眼镜 9114 / 9115 并解第一帧…"
        append("开始抓帧：\(host) 屏幕 \(screenPort) / 相机 \(cameraPort)")

        frameLock.lock()
        capturedScreen = nil
        capturedCamera = nil
        frameLock.unlock()

        captureScreenDecoder = H264FrameDecoder()
        captureCameraDecoder = H264FrameDecoder()
        let sd = captureScreenDecoder
        let cd = captureCameraDecoder

        let screen = H264StreamReceiver(host: host, port: screenPort, label: "capture-screen",
            onNAL: { [weak self] nal in
                if let frame = sd.feed(nal) { self?.collect(screen: frame, camera: nil) }
            },
            onState: { [weak self] message in self?.append("[抓帧/屏幕] \(message)") })
        let camera = H264StreamReceiver(host: host, port: cameraPort, label: "capture-camera",
            onNAL: { [weak self] nal in
                if let frame = cd.feed(nal) { self?.collect(screen: nil, camera: frame) }
            },
            onState: { [weak self] message in self?.append("[抓帧/相机] \(message)") })

        captureScreenReceiver = screen
        captureCameraReceiver = camera
        screen.start()
        camera.start()

        DispatchQueue.global().asyncAfter(deadline: .now() + 12) { [weak self] in
            self?.timeoutCapture()
        }
    }

    private func collect(screen: CGImage?, camera: CGImage?) {
        frameLock.lock()
        if let s = screen, capturedScreen == nil { capturedScreen = s }
        if let c = camera, capturedCamera == nil { capturedCamera = c }
        let s = capturedScreen
        let c = capturedCamera
        frameLock.unlock()

        guard let s = s, let c = c else {
            DispatchQueue.main.async { [weak self] in
                let which = screen != nil ? "屏幕帧 ✓ 相机帧 …" : "相机帧 ✓ 屏幕帧 …"
                self?.captureState = "已收到 \(which)"
            }
            return
        }
        finishCapture(screen: s, camera: c)
    }

    private func finishCapture(screen: CGImage, camera: CGImage) {
        stopCaptureReceivers()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.frameStore?.applyGlassesFrames(screen: screen, camera: camera)
            self.captureInProgress = false
            self.captureState = "已从眼镜抓到两帧真实画面，预览已更新"
            self.append("抓帧完成，预览源切换为眼镜实时帧")
        }
    }

    private func timeoutCapture() {
        frameLock.lock()
        let s = capturedScreen
        let c = capturedCamera
        frameLock.unlock()
        guard s == nil || c == nil else { return }

        stopCaptureReceivers()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.captureInProgress = false
            self.captureState = "抓帧超时：确认眼镜端推流服务已启动、IP/端口与 Wi-Fi 一致；也可先用相册导入两张真实图"
            self.append("抓帧超时（屏幕帧 \(s == nil ? "无" : "有") / 相机帧 \(c == nil ? "无" : "有")）")
        }
    }

    private func stopCaptureReceivers() {
        captureScreenReceiver?.stop()
        captureCameraReceiver?.stop()
        captureScreenReceiver = nil
        captureCameraReceiver = nil
    }

    // MARK: - 日志 / 计数

    private func append(_ line: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let stamp = String(format: "%.3f", Date().timeIntervalSince1970)
            self.log.append("\(stamp)  \(line)")
            if self.log.count > 200 { self.log.removeFirst() }
        }
    }

    private func bumpScreen() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.screenNALCount += 1
        }
    }

    private func bumpCamera() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cameraNALCount += 1
        }
    }
}
