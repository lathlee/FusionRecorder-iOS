//
//  RecorderSession.swift
//  FusionRecorder
//
//  离线录制架构（0.4.0）—— 全流程：
//    发现眼镜 → ADB 部署采集端 → 眼镜本地双路录 mp4 → iPhone 只计时
//    → 停止后 ADB pull 两个 mp4 → iPhone 离线合成 → 写片存相册
//
//  为什么改：0.3.x 实时推流下，两路 H264 走 WiFi TCP，链路一抖动两路同时停推，
//  旧写帧策略继续写旧帧 → 屏幕/相机同时冻结。把录制搬到眼镜本地后，
//  编码与 muxer 不依赖网络，从根上消除这个故障模式。
//
//  对齐规则：两路 mp4 的 pts 都来自眼镜 SystemClock.elapsedRealtimeNanos()/1000，
//  同一时基；OfflineCompositor 取 max(两路首帧) → 任一路读完（按短的那路）。
//

import Foundation
import Combine
import CoreGraphics
import UIKit

enum OfflinePhase: String {
    case idle = "待机"
    case deploying = "部署采集端"
    case recording = "录制中"
    case stopping = "收尾写文件"
    case pulling = "传输文件"
    case composing = "离线合成"
    case saving = "保存相册"
}

final class RecorderSession: ObservableObject {

    @Published private(set) var isRunning = false
    @Published private(set) var log: [String] = []
    @Published private(set) var captureState = "未抓帧"
    @Published private(set) var captureInProgress = false
    @Published private(set) var finishedMovieURL: URL?
    @Published private(set) var recordError: String?

    // ---- 离线流程状态 ----
    @Published private(set) var offlinePhase: OfflinePhase = .idle
    @Published private(set) var offlineProgress: Double = 0
    @Published private(set) var phaseDetail = ""
    /// 录制已用秒数（离线阶段 UI 只给计时，没有实时预览）
    @Published private(set) var recordingElapsed: Int = 0
    /// 合成进度用的已写帧数
    @Published private(set) var recordedFrameCount: Int = 0

    func clearRecordResult() {
        finishedMovieURL = nil
        recordError = nil
        offlineProgress = 0
        phaseDetail = ""
        recordedFrameCount = 0
    }

    func appendUser(_ line: String) { append(line) }

    /// 抓帧预览源（离线录制不依赖它，保留供参数预览对照）
    weak var frameStore: FrameStore?

    private let recordingCompositor = RecordingCompositor(params: FusionParams())
    var orchestrator = CaptureOrchestrator()

    private var adb: ADBClient?
    private var timer: DispatchSourceTimer?
    private var timerQueue = DispatchQueue(label: "com.lath.fusionrecorder.timer")
    private var recordStartDate: Date?

    // 远端与本地文件路径
    private let screenRemotePath = "/data/local/tmp/fusion_screen.mp4"
    private let cameraRemotePath = "/sdcard/Android/data/com.fusion.capture/files/fusion_camera.mp4"
    private var screenLocalURL: URL?
    private var cameraLocalURL: URL?
    private var outputLocalURL: URL?

    private var pullScreenProgress: Double = 0
    private var pullCameraProgress: Double = 0

    /// 抓帧用的旧解码器（参数预览/调试用；离线录制路径不调用）
    private var captureScreenReceiver: H264StreamReceiver?
    private var captureCameraReceiver: H264StreamReceiver?
    private var captureScreenDecoder = H264FrameDecoder()
    private var captureCameraDecoder = H264FrameDecoder(rotation: 180)
    private var capturedScreen: CGImage?
    private var capturedCamera: CGImage?
    private let frameLock = NSLock()

    private static func nowStamp() -> String {
        String(Int(Date().timeIntervalSince1970))
    }

    func update(params: FusionParams) {
        recordingCompositor.update(params)
    }

    var params: FusionParams { recordingCompositor.currentParams }

    private func setPhase(_ phase: OfflinePhase, _ detail: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.offlinePhase = phase
            self.phaseDetail = detail
            self.append(detail)
        }
    }

    // MARK: - 开始（对外保留 startAuto 签名，内部走离线）

    /// 手动入口：host 直接给眼镜 IP，仍走离线录制。
    func start(host: String, screenPort: UInt16, cameraPort: UInt16) {
        startOffline(host: host, iphoneHostIP: nil) { _ in }
    }

    /// 全自动入口：部署 → 本地录制 → 计时。端口参数保留兼容，离线不使用。
    func startAuto(host: String? = nil, iphoneHostIP: String? = nil,
                   screenPort: UInt16 = 9114, cameraPort: UInt16 = 9115,
                   completion: @escaping (Result<Void, Error>) -> Void) {
        startOffline(host: host, iphoneHostIP: iphoneHostIP, completion: completion)
    }

    private func startOffline(host: String?, iphoneHostIP: String?,
                              completion: @escaping (Result<Void, Error>) -> Void) {
        guard !isRunning, offlinePhase == .idle || offlinePhase == .saving else {
            completion(.failure(ADBError.connectionFailed("正在录制或收尾中")))
            return
        }
        clearRecordResult()
        setPhase(.deploying, "离线架构：部署采集端（眼镜本地录两路 mp4）")

        orchestrator.run(host: host, iphoneHostIP: iphoneHostIP) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                self.setPhase(.idle, "部署失败")
                completion(.failure(error))
            case .success(let message):
                self.append("部署完成：\(message)")
                self.connectAndStartRecording(completion: completion)
            }
        }
    }

    /// 部署完成后另建一条 ADB 连接，专管停止/pull（职责与 orchestrator 分开）。
    private func connectAndStartRecording(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let glassesIP = orchestrator.glassesIP else {
            let e = ADBError.connectionFailed("拿不到眼镜 IP")
            setPhase(.idle, "失败")
            completion(.failure(e))
            return
        }
        let client = ADBClient(host: glassesIP, port: 5555)
        client.log = { [weak self] message in self?.append("[ADB] \(message)") }
        client.connect { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                self.setPhase(.idle, "失败")
                completion(.failure(error))
            case .success:
                self.adb = client
                self.append("ADB 已连接 \(glassesIP)，启动眼镜本地录制")
                // 建好相机可写目录（/data/local/tmp 本身只有 shell 可写）并清停止标记
                client.shell(CaptureOrchestrator.prepareRecordCommand()) { [weak self] _ in
                    guard let self = self else { return }
                    let screenCmd = CaptureOrchestrator.screenRecordStartCommand()
                    guard CaptureOrchestrator.isSafeCommand(screenCmd) else {
                        completion(.failure(ADBError.connectionFailed("屏幕录制命令非法")))
                        return
                    }
                    // 屏幕录制是长驻进程，用 shellDetached 保持通道
                    client.shellDetached(screenCmd) { [weak self] screenResult in
                        guard let self = self else { return }
                        switch screenResult {
                        case .failure(let error):
                            self.setPhase(.idle, "失败")
                            completion(.failure(error))
                            return
                        case .success:
                            self.append("屏幕本地录制已启动 → \(self.screenRemotePath)")
                        }
                        let cameraCmd = CaptureOrchestrator.cameraRecordStartCommand()
                        guard CaptureOrchestrator.isSafeCommand(cameraCmd) else {
                            completion(.failure(ADBError.connectionFailed("相机录制命令非法")))
                            return
                        }
                        client.shell(cameraCmd, timeout: 30) { [weak self] cameraResult in
                            guard let self = self else { return }
                            switch cameraResult {
                            case .failure(let error):
                                self.setPhase(.idle, "失败")
                                completion(.failure(error))
                            case .success(let output):
                                self.append("相机本地录制已启动 → \(self.cameraRemotePath) "
                                            + output.trimmingCharacters(in: .whitespacesAndNewlines))
                                self.markRecordingStarted()
                                completion(.success(()))
                            }
                        }
                    }
                }
            }
        }
    }

    private func markRecordingStarted() {
        let stamp = Self.nowStamp()
        let tmp = FileManager.default.temporaryDirectory
        screenLocalURL = tmp.appendingPathComponent("fusion_screen_\(stamp).mp4")
        cameraLocalURL = tmp.appendingPathComponent("fusion_camera_\(stamp).mp4")
        outputLocalURL = tmp.appendingPathComponent("fusion_rec_\(stamp).mp4")
        pullScreenProgress = 0
        pullCameraProgress = 0
        recordStartDate = Date()
        recordingElapsed = 0
        isRunning = true
        setPhase(.recording, "眼镜正在本地录制两路 mp4；录制完点停止，会自动传输并合成")
        startTimer()
    }

    private func startTimer() {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: timerQueue)
        t.schedule(deadline: .now() + 1, repeating: 1.0)
        t.setEventHandler { [weak self] in
            guard let self = self, let start = self.recordStartDate else { return }
            let sec = Int(Date().timeIntervalSince(start))
            DispatchQueue.main.async { self.recordingElapsed = sec }
        }
        t.resume()
        timer = t
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
        recordStartDate = nil
    }

    // MARK: - 停止 → 收尾 → pull → 合成

    func stop() {
        guard isRunning, let adb = adb else { return }
        isRunning = false
        stopTimer()
        setPhase(.stopping, "通知眼镜写完两个 mp4…")

        // 屏幕：touch 标记；相机：带 STOP action 再 start 一次服务，
        // 让 worker 走 signalEndOfInputStream + drain EOS + muxer.stop()
        adb.shell(CaptureOrchestrator.stopScreenRecordCommand()) { [weak self] _ in
            guard let self = self else { return }
            adb.shell(CaptureOrchestrator.stopCameraRecordCommand(), timeout: 20) { [weak self] _ in
                guard let self = self else { return }
                self.waitFilesThenPull(adb: adb)
            }
        }
    }

    /// 轮询两个文件大小，连续两次一致且非零才算写完（最多约 10 秒）。
    private func waitFilesThenPull(adb: ADBClient) {
        let command = CaptureOrchestrator.waitFilesCommand()
        adb.shell(command, timeout: 25) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                self.fail("等待文件写完失败：\(error.localizedDescription)")
            case .success(let output):
                let text = output.trimmingCharacters(in: .whitespacesAndNewlines)
                self.append("文件就绪检查：\(text)")
                guard text.contains("READY") else {
                    self.fail("眼镜端 mp4 未写完或为空：\(text)")
                    return
                }
                self.pullFiles(adb: adb)
            }
        }
    }

    private func pullFiles(adb: ADBClient) {
        guard let screenURL = screenLocalURL,
              let cameraURL = cameraLocalURL,
              let outputURL = outputLocalURL else {
            fail("本地路径未初始化")
            return
        }
        setPhase(.pulling, "传输屏幕 mp4（0%）…")

        adb.pull(path: screenRemotePath, progress: { [weak self] ratio in
            guard let self = self else { return }
            self.pullScreenProgress = ratio
            self.updatePullProgress()
        }) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                self.fail("拉取屏幕 mp4 失败：\(error.localizedDescription)")
                return
            case .success(let data):
                do { try data.write(to: screenURL) }
                catch { self.fail("保存屏幕 mp4 失败：\(error.localizedDescription)"); return }
                self.append("屏幕 mp4 已拉取（\(data.count) 字节）")
            }

            DispatchQueue.main.async { self.phaseDetail = "传输相机 mp4（0%）…" }
            adb.pull(path: cameraRemotePath, progress: { [weak self] ratio in
                guard let self = self else { return }
                self.pullCameraProgress = ratio
                self.updatePullProgress()
            }) { [weak self] cameraResult in
                guard let self = self else { return }
                switch cameraResult {
                case .failure(let error):
                    self.fail("拉取相机 mp4 失败：\(error.localizedDescription)")
                    return
                case .success(let data):
                    do { try data.write(to: cameraURL) }
                    catch { self.fail("保存相机 mp4 失败：\(error.localizedDescription)"); return }
                    self.append("相机 mp4 已拉取（\(data.count) 字节）")
                }
                // 先读眼镜写下的绝对时间信息（首帧 pts + 真实结束时刻）
                self.readTrackMetas(adb: adb) { screenMeta, cameraMeta in
                    adb.shell("rm -f \(self.screenRemotePath) \(self.screenRemotePath).meta "
                              + "\(self.cameraRemotePath) \(self.cameraRemotePath).meta; "
                              + CaptureOrchestrator.restorePowerCommand()) { _ in }
                    self.composeOffline(screenURL: screenURL, cameraURL: cameraURL,
                                        outputURL: outputURL,
                                        screenMeta: screenMeta, cameraMeta: cameraMeta)
                }
            }
        }
    }

    /// 读取两路的 `<mp4>.meta`：第 1 行首帧绝对 pts，第 2 行结束时刻。
    private func readTrackMetas(adb: ADBClient,
                                completion: @escaping (TrackMeta?, TrackMeta?) -> Void) {
        // 先取局部常量：闭包里引用实例属性要显式 self，用局部值更干净
        let sPath = screenRemotePath
        let cPath = cameraRemotePath
        adb.shell("cat \(sPath).meta 2>/dev/null || echo 0", timeout: 10) { sResult in
            let sText = (try? sResult.get())?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
            adb.shell("cat \(cPath).meta 2>/dev/null || echo 0",
                      timeout: 10) { [weak self] cResult in
                let cText = (try? cResult.get())?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
                let sMeta = Self.parseTrackMeta(sText)
                let cMeta = Self.parseTrackMeta(cText)
                self?.append("时间标记：屏幕=\(sText.replacingOccurrences(of: "\n", with: "/")) "
                             + "相机=\(cText.replacingOccurrences(of: "\n", with: "/"))")
                completion(sMeta, cMeta)
            }
        }
    }

    private static func parseTrackMeta(_ text: String) -> TrackMeta? {
        let lines = text.split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
        guard lines.count >= 2,
              let first = Int64(lines[0]),
              let end = Int64(lines[1]),
              first > 0, end > first else { return nil }
        return TrackMeta(firstPTS: first, endPTS: end)
    }

    private func updatePullProgress() {
        let ratio = min(1.0, (pullScreenProgress + pullCameraProgress) / 2.0)
        offlineProgress = ratio
        phaseDetail = String(format: "传输 mp4（%.0f%%）…", ratio * 100)
    }

    private func composeOffline(screenURL: URL, cameraURL: URL, outputURL: URL,
                                screenMeta: TrackMeta?, cameraMeta: TrackMeta?) {
        setPhase(.composing, "离线合成中（两路按绝对 pts 对齐，按短的那路裁剪）…")
        let params = self.params
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let result = try OfflineCompositor.compose(
                    screenURL: screenURL,
                    cameraURL: cameraURL,
                    outputURL: outputURL,
                    params: params,
                    screenMeta: screenMeta,
                    cameraMeta: cameraMeta) { ratio in
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            self.offlineProgress = ratio
                            self.phaseDetail = String(
                                format: "离线合成中（%.0f%%）…", ratio * 100)
                        }
                    }
                DispatchQueue.main.async {
                    self.offlineProgress = 1
                    self.setPhase(.idle, "完成")
                    self.recordedFrameCount = result.frameCount
                    self.finishedMovieURL = result.movieURL
                    self.append("成片已保存相册：\(result.frameCount) 帧 / "
                                + String(format: "%.1fs", Double(result.durationUs) / 1e6)
                                + "（按短的那路裁剪）")
                }
            } catch {
                DispatchQueue.main.async {
                    self.fail("离线合成失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func fail(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isRunning = false
            self.stopTimer()
            self.offlinePhase = .idle
            self.offlineProgress = 0
            self.recordError = message
            self.append(message)
        }
    }

    // MARK: - 抓帧（旧调试入口，离线录制不依赖）

    func captureFrames(host: String, screenPort: UInt16, cameraPort: UInt16) {
        guard !captureInProgress else { return }
        captureInProgress = true
        captureState = "正在连接眼镜 9114 / 9115 并解第一帧…"
        append("抓帧：该入口属于实时推流调试，0.4.0 离线录制不依赖它")

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
        stopCaptureReceivers()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.frameStore?.applyGlassesFrames(screen: s, camera: c)
            self.captureInProgress = false
            self.captureState = "已从眼镜抓到两帧真实画面，预览已更新"
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
            self.captureState = "抓帧超时（0.4.0 离线录制不需要实时推流，可直接开始录制）"
        }
    }

    private func stopCaptureReceivers() {
        captureScreenReceiver?.stop()
        captureCameraReceiver?.stop()
        captureScreenReceiver = nil
        captureCameraReceiver = nil
    }

    // MARK: - 日志

    private func append(_ line: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let stamp = String(format: "%.3f", Date().timeIntervalSince1970)
            self.log.append("\(stamp)  \(line)")
            if self.log.count > 200 { self.log.removeFirst() }
        }
    }
}
