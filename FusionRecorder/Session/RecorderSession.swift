//
//  RecorderSession.swift
//  FusionRecorder
//
//  把 ADB + 双路流 + 唯一合成器 + 成片写入串起来，并给 SwiftUI 提供状态。
//
//  ★ 预览 / 抓帧 / 录制 三条路径都指向同一个 FusionCompositor：
//    · 预览：FrameStore 的两张真实帧 → FusionCompositor（FusionPreview 负责显示）
//    · 抓帧：9114 / 9115 各解一帧 → 存进 FrameStore → 立刻成为新的预览源
//    · 录制：双路实时帧 + 真实 pts → 帧队列锚点对齐 → RecordingCompositor → MovieWriter
//  参数统一由 ContentView 组装成 FusionParams 后 update 进来，不存在两套数值。
//
//  v0.2 pts 对齐（与 PROTOCOL.md §6 一致）：
//    两路帧率不同（20/30fps），不能按帧号配对。每路维护 (pts, CGImage) 队列，
//    以 t0 = min(两路首帧 pts) 为零点，按 20fps 生成目标时刻，
//    每路取「pts 不晚于目标时刻的最后一帧」送合成器 —— 静止画面自然重复上一帧。
//

import Foundation
import Combine
import CoreGraphics
import UIKit

/// 一路带时间戳的帧队列。只保留最近若干帧，按 pts 升序（采集端写 TCP 即时间戳）。
private final class TimedFrameQueue {
    private var frames: [(pts: Int64, image: CGImage)] = []
    private let capacity = 300          // 15 秒 @20fps，足够应对抖动

    func append(pts: Int64, image: CGImage) {
        frames.append((pts, image))
        if frames.count > capacity {
            frames.removeFirst(frames.count - capacity)
        }
    }

    /// pts 不晚于 target 的最后一帧。没有更早帧时退回第一帧。
    func anchor(before target: Int64) -> (image: CGImage, pts: Int64)? {
        guard let first = frames.first else { return nil }
        var chosen = first
        for f in frames {
            if f.pts <= target { chosen = f } else { break }
        }
        return (chosen.image, chosen.pts)
    }

    var firstPTS: Int64? { frames.first?.pts }
    var isEmpty: Bool { frames.isEmpty }
    func clear() { frames.removeAll() }
}

final class RecorderSession: ObservableObject {

    @Published private(set) var isRunning = false
    @Published private(set) var log: [String] = []
    @Published private(set) var screenNALCount = 0
    @Published private(set) var cameraNALCount = 0
    /// 录制中的实时合成帧（就是成片里正在写的那一帧，只是缩小显示）
    @Published private(set) var livePreview: CGImage?
    @Published private(set) var captureState = "未抓帧"
    @Published private(set) var captureInProgress = false
    /// v0.2：成片已写好的通知（URL 为相册里的临时 mp4，已同步到相册）
    @Published private(set) var finishedMovieURL: URL?
    @Published private(set) var recordError: String?
    /// 已写入帧数（UI 录制页显示）
    @Published private(set) var recordedFrameCount: Int = 0

    func clearRecordResult() {
        finishedMovieURL = nil
        recordError = nil
    }

    /// UI 侧追加一条可见日志（保留了时间戳格式）
    func appendUser(_ line: String) { append(line) }

    /// 抓到的真实帧交给它保存，随后自动成为预览源
    weak var frameStore: FrameStore?

    private let recordingCompositor = RecordingCompositor(params: FusionParams())
    private var screenDecoder = H264FrameDecoder()
    // 眼镜摄像头 sensor orientation=180，采集端输出倒像；相机流解码后旋转补正。
    // 屏幕流不需要旋转。抓帧预览与录制共用同一 decoder 配置，保证"预览=成片"。
    private var cameraDecoder = H264FrameDecoder(rotation: 180)

    /// 全自动部署编排器（发现 → ADB → push → 启动两路）
    /// 由 ContentView 注入并共用同一实例，便于 UI 观察状态
    var orchestrator = CaptureOrchestrator()

    private var adb: ADBClient?
    private var screenReceiver: H264StreamReceiver?
    private var cameraReceiver: H264StreamReceiver?
    /// 全自动模式：采集端主动连 iPhone，用监听端（与上面的客户端并存）
    private var screenListener: H264StreamListener?
    private var cameraListener: H264StreamListener?

    private var captureScreenReceiver: H264StreamReceiver?
    private var captureCameraReceiver: H264StreamReceiver?
    private var captureScreenDecoder = H264FrameDecoder()
    private var captureCameraDecoder = H264FrameDecoder(rotation: 180)

    private let frameLock = NSLock()
    private var liveScreen: CGImage?
    private var liveCamera: CGImage?
    private var capturedScreen: CGImage?
    private var capturedCamera: CGImage?

    // ---- v0.2：pts 对齐帧队列 + CFR 定时输出 + 成片写入 ----
    private var screenQueue = TimedFrameQueue()
    private var cameraQueue = TimedFrameQueue()
    private var movieWriter: MovieWriter?
    private var cfrTimer: DispatchSourceTimer?
    private let cfrQueue = DispatchQueue(label: "com.lath.fusionrecorder.cfr")
    private var timelineOriginUs: Int64?
    /// 建立时间零点那一刻的真实墙钟（微秒）。成片 pts 跟随真实经过时间，
    /// 而不是"帧序号 × 50ms"——后者在合成慢（写帧少）时会把成片时长压缩，
    /// 表现为"只保存了前面一段，后面没了"。
    private var wallClockBaseUs: Int64?
    private var outputFrameIndex: Int64 = 0
    private let outputFPS: Int64 = 20

    /// 单调墙钟微秒（DispatchTime，不受系统时间调整影响）
    private static func nowWallUs() -> Int64 {
        Int64(DispatchTime.now().uptimeNanoseconds / 1_000)
    }

    /// UI 在每次参数变化时调用，保证录制用的就是预览里那组数值
    func update(params: FusionParams) {
        recordingCompositor.update(params)
    }

    var params: FusionParams { recordingCompositor.currentParams }

    // MARK: - 录制

    /// 手动模式：iPhone 主动连眼镜（眼镜端是 server）。用于老 PoC / 抓帧对照。
    func start(host: String, screenPort: UInt16, cameraPort: UInt16) {
        beginPipeline(screenPort: screenPort, cameraPort: cameraPort, listen: false, host: host)
        // 手动模式也尝试 ADB 握手（老流程：只连不部署）
        let client = ADBClient(host: host, port: 5555)
        client.log = { [weak self] message in self?.append("[ADB] \(message)") }
        adb = client
        client.connect { [weak self] result in
            switch result {
            case .success: self?.append("ADB 握手完成")
            case .failure(let error): self?.append("ADB 连接失败：\(error.localizedDescription)（流仍可单独接收）")
            }
        }
    }

    /// 全自动模式：先部署眼镜端，再让 iPhone 监听 9114/9115 等采集端主动接入。
    func startAuto(host: String? = nil, iphoneHostIP: String? = nil,
                   screenPort: UInt16 = 9114, cameraPort: UInt16 = 9115,
                   completion: @escaping (Result<Void, Error>) -> Void) {
        guard !isRunning else {
            completion(.failure(ADBError.connectionFailed("正在录制中")))
            return
        }
        append("全自动：发现眼镜 → 部署采集端 → 监听两路 → 录制写相册")
        orchestrator.run(host: host, iphoneHostIP: iphoneHostIP) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let message):
                self.append("部署完成：\(message)")
                // 采集端已下发启动命令，立刻开监听；采集端会主动连过来
                self.beginPipeline(screenPort: screenPort, cameraPort: cameraPort,
                                   listen: true, host: nil)
                completion(.success(()))
            }
        }
    }

    /// 管线公共部分：解码器 / 帧队列 / writer / CFR；两种模式只差接收方式。
    private func beginPipeline(screenPort: UInt16, cameraPort: UInt16,
                               listen: Bool, host: String?) {
        guard !isRunning else { return }
        isRunning = true
        livePreview = nil
        finishedMovieURL = nil
        recordError = nil
        recordedFrameCount = 0
        append("启动：\(listen ? "监听" : "连接") 屏幕 \(screenPort) / 相机 \(cameraPort)")
        append("合成参数：\(params.fingerprint)")
        append("v0.3：pts 锚点对齐，\(outputFPS)fps CFR 输出，成片写相册")

        // 成片分辨率 = 合成画布 = 预览画布（三者同一份 FusionParams）
        let size = params.renderSize
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fusion_rec_\(Int(Date().timeIntervalSince1970)).mp4")
        let writer = MovieWriter(width: size.width, height: size.height)
        do {
            try writer.start(outputURL: url)
            movieWriter = writer
            append("编码器就绪：\(size.width)×\(size.height) / H264 / \(outputFPS)fps")
        } catch {
            recordError = "编码器启动失败：\(error.localizedDescription)"
            append(recordError!)
            isRunning = false
            return
        }

        screenDecoder = H264FrameDecoder()
        cameraDecoder = H264FrameDecoder(rotation: 180)
        frameLock.lock()
        screenQueue.clear()
        cameraQueue.clear()
        timelineOriginUs = nil
        wallClockBaseUs = nil
        outputFrameIndex = 0
        frameLock.unlock()

        let onScreenNAL: (Data) -> Void = { [weak self] nal in
            self?.bumpScreen()
            self?.handleLive(nal, isScreen: true)
        }
        let onCameraNAL: (Data) -> Void = { [weak self] nal in
            self?.bumpCamera()
            self?.handleLive(nal, isScreen: false)
        }

        if listen {
            // 全自动：眼镜主动连过来
            let sl = H264StreamListener(port: screenPort, label: "screen",
                onNAL: onScreenNAL,
                onState: { [weak self] message in self?.append("[屏幕/监听] \(message)") })
            let cl = H264StreamListener(port: cameraPort, label: "camera",
                onNAL: onCameraNAL,
                onState: { [weak self] message in self?.append("[相机/监听] \(message)") })
            screenListener = sl
            cameraListener = cl
            sl.start()
            cl.start()
        } else if let host = host {
            // 手动：iPhone 主动连眼镜
            let screen = H264StreamReceiver(host: host, port: screenPort, label: "screen",
                onNAL: onScreenNAL,
                onState: { [weak self] message in self?.append("[屏幕] \(message)") })
            let camera = H264StreamReceiver(host: host, port: cameraPort, label: "camera",
                onNAL: onCameraNAL,
                onState: { [weak self] message in self?.append("[相机] \(message)") })
            screenReceiver = screen
            cameraReceiver = camera
            screen.start()
            camera.start()
        }

        startCFRTimer()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        stopCFRTimer()

        screenReceiver?.stop()
        cameraReceiver?.stop()
        screenListener?.stop()
        cameraListener?.stop()
        screenListener = nil
        cameraListener = nil
        // 通知眼镜端停相机流（屏幕流靠 TCP 断开，心跳最多 1 秒感知）
        orchestrator.stop { [weak self] in
            self?.append("已通知眼镜端停止采集")
        }
        adb?.disconnect()
        screenDecoder.invalidate()
        cameraDecoder.invalidate()

        frameLock.lock()
        liveScreen = nil
        liveCamera = nil
        screenQueue.clear()
        cameraQueue.clear()
        frameLock.unlock()

        guard let writer = movieWriter, writer.writtenFrames > 0 else {
            movieWriter?.cancel()
            movieWriter = nil
            append("已停止（没有可写入的帧）")
            // 必须通知 UI：否则 ContentView 的 isFinishing 靠 recordError/finishedMovieURL
            // 的 onChange 退出，两者都不变就永远卡在「正在封装成片并保存相册」。
            let msg = "没有收到可写入的帧：确认眼镜两路流都已接入（9114/9115）、屏幕点亮，再点「全自动录制」"
            recordError = msg
            append(msg)
            return
        }
        append("正在封装成片（\(writer.writtenFrames) 帧）…")
        writer.finish { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let url):
                    self.finishedMovieURL = url
                    self.append("成片已保存到相册：\(url.lastPathComponent)")
                case .failure(let error):
                    self.recordError = error.localizedDescription
                    self.append("成片失败：\(error.localizedDescription)")
                }
                self.movieWriter = nil
            }
        }
    }

    /// 每来一个 NAL：解出帧 → 带 pts 入对应队列。
    /// 合成不再在这里做，改由 CFR 定时器按统一时间轴驱动（避免帧率不同导致错配）。
    private func handleLive(_ nal: Data, isScreen: Bool) {
        let decoder = isScreen ? screenDecoder : cameraDecoder
        guard let result = decoder.feedWithPTS(nal) else { return }

        frameLock.lock()
        if isScreen {
            screenQueue.append(pts: result.ptsUs, image: result.image)
        } else {
            cameraQueue.append(pts: result.ptsUs, image: result.image)
        }
        // t0 = 两路都有帧后，取两路首帧中较早者（PROTOCOL.md §6）
        if timelineOriginUs == nil {
            if let s = screenQueue.firstPTS, let c = cameraQueue.firstPTS {
                timelineOriginUs = min(s, c)
                // 同时记下真实墙钟：成片时间轴按真实经过时间推进，
                // 写帧慢/掉帧时后续帧仍拿到正确的 pts，不会把时长压缩。
                wallClockBaseUs = Self.nowWallUs()
                append("两路首帧 pts 差 \(abs(s - c)) μs，时间零点已建立")
            }
        }
        let s = liveScreen
        let c = liveCamera
        frameLock.unlock()

        // 录制页的实时预览：仍显示两路最新帧的合成结果（与写入帧同源）
        if isScreen {
            frameLock.lock(); liveScreen = result.image; frameLock.unlock()
        } else {
            frameLock.lock(); liveCamera = result.image; frameLock.unlock()
        }
        if let s = s, let c = c, let composed = recordingCompositor.compose(screen: s, camera: c) {
            DispatchQueue.main.async { [weak self] in self?.livePreview = composed }
        }
    }

    // MARK: - CFR 定时输出（20fps）

    private func startCFRTimer() {
        let timer = DispatchSource.makeTimerSource(queue: cfrQueue)
        timer.schedule(deadline: .now() + 0.1, repeating: .milliseconds(1000 / Int(outputFPS)))
        timer.setEventHandler { [weak self] in self?.tickCFR() }
        timer.resume()
        cfrTimer = timer
    }

    private func stopCFRTimer() {
        cfrTimer?.cancel()
        cfrTimer = nil
    }

    private func tickCFR() {
        guard isRunning, let writer = movieWriter else { return }
        frameLock.lock()
        let origin = timelineOriginUs
        let baseUs = wallClockBaseUs
        let sEmpty = screenQueue.isEmpty
        let cEmpty = cameraQueue.isEmpty
        frameLock.unlock()
        guard let t0 = origin, let base = baseUs, !sEmpty, !cEmpty else { return }

        // ★ pts 跟随真实墙钟：targetUs = 时间零点 + 真实经过时间。
        // 不再用 outputFrameIndex×50ms——那样合成一慢（1280×720 逐像素 Swift 很重），
        // 写帧数就落后，成片时长被压成"帧数/20fps"，丢掉后半段。
        // 用真实时间后，即使掉帧，后续帧也拿到正确 pts，成片时长 = 实际录制时长。
        let elapsedUs = max(0, Self.nowWallUs() - base)
        let targetUs = t0 + elapsedUs
        frameLock.lock()
        let s = screenQueue.anchor(before: targetUs)
        let c = cameraQueue.anchor(before: targetUs)
        frameLock.unlock()
        guard let s = s, let c = c else { return }

        guard let composed = recordingCompositor.compose(screen: s.image, camera: c.image) else { return }
        do {
            // 用真实 CFR 时刻作 pts：掉帧时后面的帧仍按真实时间写，时长不缩水
            try writer.append(frame: composed, presentationTimeUs: targetUs)
            outputFrameIndex += 1
            if outputFrameIndex % 20 == 0 {
                DispatchQueue.main.async { [weak self] in
                    self?.recordedFrameCount = Int(writer.writtenFrames)
                }
            }
            if outputFrameIndex % 40 == 0 {
                append("已写 \(outputFrameIndex) 帧 / \(String(format: "%.1f", Double(elapsedUs) / 1e6))s")
            }
        } catch {
            recordError = error.localizedDescription
            append("写帧失败：\(error.localizedDescription)")
            stop()
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
        captureCameraDecoder = H264FrameDecoder(rotation: 180)
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
