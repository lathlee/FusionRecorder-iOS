//
//  OfflineCompositor.swift
//  FusionRecorder
//
//  离线合成（0.4.0 离线录制架构的核心）：
//    眼镜本地录的两个 mp4 拉回 iPhone 后，在这里按绝对 pts 对齐、逐帧合成、写成片。
//
//  为什么这样改：
//    实时推流架构（0.3.x）里，两路 H264 走 WiFi TCP，任何链路抖动都会同时停推；
//    旧写帧策略在停推期间继续写旧帧，视觉上就是屏幕/相机同时冻结。把录制搬到
//    眼镜本地后，编码和 muxer 完全不依赖网络，从根上消除了这个故障模式。
//
//  对齐规则（用户确认「按短的那路」）：
//    · 两路 mp4 的 presentationTimeUs 都来自眼镜的 SystemClock.elapsedRealtimeNanos()，
//      同一时基，可以直接比较；
//    · 共享区间起点 = max(两路首帧 pts)，终点 = 任一路读完（短的那路）；
//    · 输出恒定 20fps，每 50ms 取两路「pts 不晚于目标时刻的最后一帧」送合成器；
//    · 相机帧做 180° 旋转补正（眼镜 sensor orientation=180），与 0.3.x 实时路径一致。
//
//  复用：FusionCompositor.render（唯一合成实现）+ MovieWriter（写片/相册）。
//  绝不在这里另写一套画面效果，保证「预览 = 成片同源」仍然成立。
//

import Foundation
import AVFoundation
import CoreMedia
import CoreVideo
import CoreGraphics
import CoreImage
import UIKit

enum OfflineComposeError: Error, LocalizedError {
    case noVideoTrack(String)
    case readerSetupFailed(String)
    case readerFailed(String)
    case noFrames
    case writerFailed(String)

    var errorDescription: String? {
        switch self {
        case .noVideoTrack(let p): return "没有视频轨：\(p)"
        case .readerSetupFailed(let p): return "读取器初始化失败：\(p)"
        case .readerFailed(let s): return "读取失败：\(s)"
        case .noFrames: return "两个 mp4 里没有可合成的帧"
        case .writerFailed(let s): return "写片失败：\(s)"
        }
    }
}

/// 单路 mp4 的顺序读帧器。内部维护「下一帧」预读，
/// frame(atOrBefore:) 返回不晚于目标时刻的最新帧，天然实现重复帧/不同帧率对齐。
private final class Mp4FrameReader {

    struct Frame {
        let image: CGImage
        let ptsUs: Int64
    }

    private let reader: AVAssetReader
    private let output: AVAssetReaderTrackOutput
    private let ciContext = CIContext()
    private let rotation: Int
    private let label: String

    private var nextFrame: Frame?
    private(set) var lastDelivered: Frame?
    private var finished = false

    /// 首帧 pts（不消费帧），用于计算两路共享区间起点
    private(set) var firstPTS: Int64?
    private(set) var durationUs: Int64 = 0

    init(url: URL, rotation: Int, label: String) throws {
        self.rotation = rotation
        self.label = label

        let asset = AVAsset(url: url)
        let duration = asset.duration
        if duration.isValid && duration.seconds.isFinite {
            durationUs = Int64(duration.seconds * 1_000_000)
        }
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw OfflineComposeError.noVideoTrack(label)
        }
        guard let r = try? AVAssetReader(asset: asset) else {
            throw OfflineComposeError.readerSetupFailed(label)
        }
        let out = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        out.alwaysCopiesSampleData = false
        guard r.canAdd(out) else {
            throw OfflineComposeError.readerSetupFailed(label + " (canAdd false)")
        }
        r.add(out)
        guard r.startReading() else {
            throw OfflineComposeError.readerSetupFailed(label + " (startReading false)")
        }
        reader = r
        output = out

        nextFrame = readOne()
        firstPTS = nextFrame?.ptsUs ?? lastDelivered?.ptsUs
    }

    private func readOne() -> Frame? {
        if finished { return nil }
        guard let sample = output.copyNextSampleBuffer() else {
            finished = true
            if reader.status == .failed {
                NSLog("[离线合成] %@ 读取失败: %@", label,
                      reader.error?.localizedDescription ?? "未知")
            }
            return nil
        }
        let ptsUs = Int64(sample.presentationTimeStamp.seconds * 1_000_000)
        guard let buffer = CMSampleBufferGetImageBuffer(sample) else {
            return readOne()   // 非图像样本，跳到下一帧
        }

        var ci = CIImage(cvImageBuffer: buffer)
        // 眼镜摄像头 sensor orientation=180，离线 mp4 里同样是倒像；
        // 与 H264FrameDecoder 的实时路径使用同一补正方式。
        if rotation == 180 {
            ci = ci.oriented(.down)
        } else if rotation == 90 {
            ci = ci.oriented(.left)
        } else if rotation == 270 {
            ci = ci.oriented(.right)
        }
        guard let cg = ciContext.createCGImage(ci, from: ci.extent) else {
            return readOne()
        }
        return Frame(image: cg, ptsUs: ptsUs)
    }

    /// 返回 pts 不晚于 target 的最后一帧；没有更晚帧时重复上一帧。
    func frame(atOrBefore target: Int64) -> Frame? {
        while let f = nextFrame, f.ptsUs <= target {
            lastDelivered = f
            nextFrame = readOne()
        }
        return lastDelivered
    }

    /// 该路是否已经读到文件尾（用于「按短的那路」裁剪）
    var exhausted: Bool { nextFrame == nil && finished }

    func cancel() {
        reader.cancelReading()
    }
}

/// 离线合成结果
struct OfflineComposeResult {
    let movieURL: URL
    let frameCount: Int
    let durationUs: Int64
    let screenFrames: Int
    let cameraFrames: Int
}

final class OfflineCompositor {

    /// 输出帧率与 0.3.x 实时路径一致
    static let outputFPS: Int64 = 20

    /// 合成并写片。progress 在后台线程调用，调用方需自行切主线程更新 UI。
    static func compose(screenURL: URL,
                        cameraURL: URL,
                        outputURL: URL,
                        params: FusionParams,
                        progress: ((Double) -> Void)? = nil) throws -> OfflineComposeResult {
        let screen = try Mp4FrameReader(url: screenURL, rotation: 0, label: "屏幕")
        let camera = try Mp4FrameReader(url: cameraURL, rotation: 180, label: "相机")

        guard let s0 = screen.firstPTS, let c0 = camera.firstPTS else {
            screen.cancel(); camera.cancel()
            throw OfflineComposeError.noFrames
        }
        // 共享区间起点：两路都已经有画面的时刻
        let startPTS = max(s0, c0)
        // 终点估算：任一路「首帧 + 时长」的较小者，仅用于进度条
        let sEnd = s0 + screen.durationUs
        let cEnd = c0 + camera.durationUs
        let endPTS = min(sEnd, cEnd)
        let totalUs = max(1, endPTS - startPTS)

        let size = params.renderSize
        let writer = MovieWriter(width: size.width, height: size.height)
        try writer.start(outputURL: outputURL)

        let stepUs: Int64 = 1_000_000 / outputFPS
        var target = startPTS
        var written = 0
        var lastReport = 0

        defer {
            screen.cancel()
            camera.cancel()
        }

        while true {
            let sf = screen.frame(atOrBefore: target)
            let cf = camera.frame(atOrBefore: target)
            guard let s = sf, let c = cf else { break }

            guard let composed = FusionCompositor.render(
                    screen: s.image, camera: c.image, params: params) else {
                continue
            }
            try writer.append(frame: composed, presentationTimeUs: target - startPTS)
            written += 1

            if written - lastReport >= 20 {          // 每秒报一次进度
                lastReport = written
                let ratio = min(1.0, Double(target - startPTS) / Double(totalUs))
                progress?(ratio)
            }

            // 按短的那路裁剪：任一路读完即停，但已经写入的这一帧保留
            if screen.exhausted || camera.exhausted { break }
            if target - startPTS >= totalUs { break }
            if written > 20 * 3600 * 4 { break }     // 4 小时硬上限，防死循环
            target += stepUs
        }

        guard written > 0 else {
            writer.cancel()
            throw OfflineComposeError.noFrames
        }

        let result = OfflineComposeResult(
            movieURL: outputURL,
            frameCount: written,
            durationUs: Int64(written) * stepUs,
            screenFrames: written,
            cameraFrames: written)

        // finish 是异步的（写 moov + 存相册），用 semaphore 同步等待，
        // 让调用方拿到最终 URL；整个 compose 本身已在后台队列执行。
        let sem = DispatchSemaphore(value: 0)
        var finishResult: Result<URL, Error>?
        writer.finish { finishRes in
            finishResult = finishRes
            sem.signal()
        }
        sem.wait()
        switch finishResult {
        case .success(let url)?:
            return OfflineComposeResult(movieURL: url,
                                        frameCount: result.frameCount,
                                        durationUs: result.durationUs,
                                        screenFrames: result.screenFrames,
                                        cameraFrames: result.cameraFrames)
        case .failure(let error)?:
            throw OfflineComposeError.writerFailed(error.localizedDescription)
        case nil:
            throw OfflineComposeError.writerFailed("finish 未回调")
        }
    }
}
