//
//  RecorderSession.swift
//  FusionRecorder
//
//  把 ADB + 双路流 + 视频管线串起来，并给 SwiftUI 提供状态。
//  v0.1：能连、能看到两路 NAL 计数；合成/写相册是 TODO（见 VideoPipeline.swift）。
//

import Foundation
import Combine

final class RecorderSession: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var log: [String] = []
    @Published private(set) var screenNALCount = 0
    @Published private(set) var cameraNALCount = 0

    private var adb: ADBClient?
    private var screenReceiver: H264StreamReceiver?
    private var cameraReceiver: H264StreamReceiver?

    private let screenDecoder = H264Decoder()
    private let cameraDecoder = H264Decoder()
    private let compositor = MetalCompositor()
    private let encoder = H264Encoder()
    private let writer = MovieWriter()

    func start(host: String, screenPort: UInt16, cameraPort: UInt16) {
        guard !isRunning else { return }
        isRunning = true
        append("启动：ADB \(host):5555 / 屏幕 \(screenPort) / 相机 \(cameraPort)")
        append("Metal 可用：\(compositor.isAvailable)")

        let client = ADBClient(host: host, port: 5555)
        client.log = { [weak self] message in
            self?.append("[ADB] \(message)")
        }
        adb = client
        client.connect { [weak self] result in
            switch result {
            case .success:
                self?.append("ADB 握手完成")
            case .failure(let error):
                self?.append("ADB 连接失败：\(error.localizedDescription)")
            }
        }

        let screen = H264StreamReceiver(host: host, port: screenPort, label: "screen",
            onNAL: { [weak self] _ in self?.bumpScreen() },
            onState: { [weak self] message in self?.append("[屏幕] \(message)") })
        let camera = H264StreamReceiver(host: host, port: cameraPort, label: "camera",
            onNAL: { [weak self] _ in self?.bumpCamera() },
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
        encoder.invalidate()
        append("已停止（v0.1 骨架未产出成片）")
    }

    // MARK: - 私有

    private func append(_ line: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let stamp = String(format: "%.3f", Date().timeIntervalSince1970)
            let entry = "\(stamp)  \(line)"
            self.log.append(entry)
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
