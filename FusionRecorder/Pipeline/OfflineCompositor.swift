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

/// 一路录制文件的绝对时间信息（来自眼镜写的 `<mp4>.meta` 两行）。
struct TrackMeta {
    /// 首帧的绝对 pts（elapsedRealtime 微秒）。MediaMuxer 会把 mp4 内首帧归一化成 0，
    /// 靠这个偏移才能把两路放回同一时间轴。
    let firstPTS: Int64
    /// 真实结束时刻（同钟）。VFR 下 mp4 自带 duration 可能明显偏短。
    let endPTS: Int64
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
    /// 加回被 MediaMuxer 抹掉的绝对起点，使两路 pts 落在同一时基上
    private let ptsOffsetUs: Int64

    private var nextFrame: Frame?
    private(set) var lastDelivered: Frame?
    private var finished = false

    /// 首帧 pts（不消费帧），用于计算两路共享区间起点
    private(set) var firstPTS: Int64?
    private(set) var durationUs: Int64 = 0

    init(url: URL, rotation: Int, label: String, ptsOffsetUs: Int64 = 0) throws {
        self.rotation = rotation
        self.label = label
        self.ptsOffsetUs = ptsOffsetUs

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
        let rawUs = Int64(sample.presentationTimeStamp.seconds * 1_000_000)
        let ptsUs = rawUs + ptsOffsetUs
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
    /// 0.5.0：成片里到底有没有声音（眼镜没录到音轨时为 false）
    var hasAudio: Bool = false
}

final class OfflineCompositor {

    /// 输出帧率与 0.3.x 实时路径一致
    static let outputFPS: Int64 = 20

    /// 合成并写片。progress 在后台线程调用，调用方需自行切主线程更新 UI。
    ///
    /// - parameters:
    ///   - screenMeta / cameraMeta: 眼镜在录制结束时写的绝对时间信息
    ///     （首帧 pts + 结束时刻）。缺省时退回「mp4 从 0 开始 + 自带时长」，
    ///     那样两路启动先后会被忽略，同步精度差。
    ///   - audioURL / audioMeta: 0.5.0 新增。眼镜录的麦克风音轨（独立 .m4a）
    ///     与它的绝对首帧 pts。传 nil 就出无声片；有就用 AVMutableComposition
    ///     把音轨按同一时间轴剪好并进去，音量为 `params.audioVolume`。
    static func compose(screenURL: URL,
                        cameraURL: URL,
                        outputURL: URL,
                        params: FusionParams,
                        screenMeta: TrackMeta? = nil,
                        cameraMeta: TrackMeta? = nil,
                        audioURL: URL? = nil,
                        audioMeta: TrackMeta? = nil,
                        progress: ((Double) -> Void)? = nil) throws -> OfflineComposeResult {
        let screen = try Mp4FrameReader(url: screenURL, rotation: 0, label: "屏幕",
                                        ptsOffsetUs: screenMeta?.firstPTS ?? 0)
        let camera = try Mp4FrameReader(url: cameraURL, rotation: 180, label: "相机",
                                        ptsOffsetUs: cameraMeta?.firstPTS ?? 0)

        guard let s0 = screen.firstPTS, let c0 = camera.firstPTS else {
            screen.cancel(); camera.cancel()
            throw OfflineComposeError.noFrames
        }
        // 共享区间起点：两路都已经有画面的时刻
        let startPTS = max(s0, c0)
        // 终点：优先用眼镜写下的真实结束时刻（meta），否则退回「首帧 + 时长」。
        // 只用于进度条和终止条件；若两者都没有有效值，绝不能拿 0 当终点。
        let sEnd = screenMeta?.endPTS ?? (s0 + screen.durationUs)
        let cEnd = cameraMeta?.endPTS ?? (c0 + camera.durationUs)
        let estimatedEnd = min(sEnd, cEnd)
        let hasEstimate = estimatedEnd > startPTS
        let totalUs = hasEstimate ? estimatedEnd - startPTS : 1

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

        // ★ 关键：终止条件必须由时间轴决定，不能由「哪一路先读完」决定。
        // 屏幕路是 VFR 录制，画面静止时可能只有几帧 —— 它「读完」不代表视频只有几秒。
        // 只有拿不到结束标记、也没有有效时长时，才退回用 exhausted 兜底。
        while true {
            if hasEstimate && target - startPTS >= totalUs { break }
            if !hasEstimate && (screen.exhausted || camera.exhausted) { break }
            if written > 20 * 3600 * 4 { break }     // 4 小时硬上限，防死循环

            // CIContext.createCGImage 产出的是 autoreleased CGImage。合成几十秒的
            // 视频会有上千帧，不在每帧 drain autorelease pool 的话内存会线性涨到 GB 级。
            // frame(atOrBefore:) 在该路读完后会一直返回最后一帧，天然实现「静止画面重复」。
            let composed: CGImage? = autoreleasepool {
                guard let s = screen.frame(atOrBefore: target),
                      let c = camera.frame(atOrBefore: target) else { return nil }
                return FusionCompositor.render(screen: s.image, camera: c.image, params: params)
            }
            if let composed = composed {
                try writer.append(frame: composed, presentationTimeUs: target - startPTS)
                written += 1
                if written - lastReport >= 20 {      // 每秒报一次进度
                    lastReport = written
                    let ratio = hasEstimate
                        ? min(1.0, Double(target - startPTS) / Double(totalUs)) : 0
                    progress?(ratio)
                }
            }
            // target 必须无条件前进，否则 composed == nil 时会死循环
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

        // finish 是异步的（写 moov），用 semaphore 同步等待，
        // 让调用方拿到最终 URL；整个 compose 本身已在后台队列执行。
        // 0.5.0：这里只写「画面」，不直接存相册 —— 音轨还要先并进来。
        let sem = DispatchSemaphore(value: 0)
        var finishResult: Result<URL, Error>?
        writer.finishWithoutSaving { finishRes in
            finishResult = finishRes
            sem.signal()
        }
        sem.wait()
        guard case .success(let silentURL)? = finishResult else {
            if case .failure(let error)? = finishResult {
                throw OfflineComposeError.writerFailed(error.localizedDescription)
            }
            throw OfflineComposeError.writerFailed("finish 未回调")
        }

        // 把音轨并进刚写好的无声成片
        var finalURL = silentURL
        var hasAudio = false
        if let audioURL = audioURL {
            if let muxed = muxAudio(videoURL: silentURL,
                                    audioURL: audioURL,
                                    audioMeta: audioMeta,
                                    startPTS: startPTS,
                                    totalUs: result.durationUs,
                                    volume: params.audioVolume) {
                finalURL = muxed
                hasAudio = true
            } else {
                NSLog("[离线合成] 音轨并入失败，成片将无声音")
            }
        }

        // 存相册
        let saveSem = DispatchSemaphore(value: 0)
        var saved: Result<URL, Error>?
        MovieWriter.saveToAlbum(url: finalURL) { res in
            saved = res
            saveSem.signal()
        }
        saveSem.wait()
        switch saved {
        case .success(let url)?:
            return OfflineComposeResult(movieURL: url,
                                        frameCount: result.frameCount,
                                        durationUs: result.durationUs,
                                        screenFrames: result.screenFrames,
                                        cameraFrames: result.cameraFrames,
                                        hasAudio: hasAudio)
        case .failure(let error)?:
            throw OfflineComposeError.writerFailed(error.localizedDescription)
        case nil:
            throw OfflineComposeError.writerFailed("存相册未回调")
        }
    }

    // MARK: - 音轨并入（0.5.0）

    /// 把眼镜录的 `.m4a` 按绝对时间对齐并进成片，并施加音量增益。
    ///
    /// 为什么用 AVMutableComposition 而不是手写音频重编码：
    /// 手写 CMSampleBuffer 拷贝 + 增益在没 Mac 的环境里无法本地验证，风险太高；
    /// composition + AVAssetExportSession 是系统级成熟路径，音轨剪裁/对齐都由它负责。
    ///
    /// 音量的落地方式：
    ///  · `volume ≈ 1` 用 passthrough 导出 —— 视频不重编码，画质零损失；
    ///  · 需要改音量时 audioMix 只对音轨生效，但 passthrough 会忽略 audioMix，
    ///    所以这时才退到最高质量预设（640×480 素材重编码代价很小）。
    ///
    /// - returns: 合并成功后的临时文件 URL；失败返回 nil（成片退回无声版）
    private static func muxAudio(videoURL: URL,
                                 audioURL: URL,
                                 audioMeta: TrackMeta?,
                                 startPTS: Int64,
                                 totalUs: Int64,
                                 volume: Double) -> URL? {
        let audioAsset = AVAsset(url: audioURL)
        guard let audioTrack = audioAsset.tracks(withMediaType: .audio).first else {
            NSLog("[离线合成] m4a 里没有音轨")
            return nil
        }
        let videoAsset = AVAsset(url: videoURL)
        guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
            NSLog("[离线合成] 无声成片里没有视频轨")
            return nil
        }

        let comp = AVMutableComposition()
        guard let compVideo = comp.addMutableTrack(withMediaType: .video,
                                                  preferredTrackID: kCMPersistentTrackID_Invalid),
              let compAudio = comp.addMutableTrack(withMediaType: .audio,
                                                  preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return nil
        }
        let videoRange = CMTimeRange(start: .zero, duration: videoAsset.duration)
        do {
            try compVideo.insertTimeRange(videoRange, of: videoTrack, at: .zero)
        } catch {
            NSLog("[离线合成] 插入视频轨失败: %@", error.localizedDescription)
            return nil
        }

        // 音频文件内部 pts 从 0 开始，绝对起点是 audioMeta.firstPTS。
        // 成片时间轴 0 对应 startPTS，所以音频要么整体后移、要么掐掉开头那一段。
        let audioStartAbs = audioMeta?.firstPTS ?? startPTS
        let shiftUs = audioStartAbs - startPTS
        let insertAt = CMTime(value: max(0, shiftUs), timescale: 1_000_000)
        let skip = CMTime(value: max(0, -shiftUs), timescale: 1_000_000)
        let audioTotal = audioAsset.duration
        guard audioTotal > skip else {
            NSLog("[离线合成] 音轨比画面起点还早结束，跳过（audio=%.2fs skip=%.2fs）",
                  audioTotal.seconds, skip.seconds)
            return nil
        }
        var usable = CMTimeSubtract(audioTotal, skip)
        // 不能超过成片长度
        let room = CMTimeSubtract(CMTime(value: totalUs, timescale: 1_000_000), insertAt)
        if room.isValid && room > .zero && usable > room { usable = room }
        guard usable > .zero else { return nil }

        do {
            try compAudio.insertTimeRange(
                CMTimeRange(start: skip, duration: usable), of: audioTrack, at: insertAt)
        } catch {
            NSLog("[离线合成] 插入音轨失败: %@", error.localizedDescription)
            return nil
        }

        let needsGain = abs(volume - 1.0) > 0.011
        let mix = AVMutableAudioMix()
        if needsGain {
            let params = AVMutableAudioMixInputParameters(track: compAudio)
            params.setVolume(Float(max(0, volume)), at: .zero)
            mix.inputParameters = [params]
        }

        let out = videoURL.deletingLastPathComponent()
            .appendingPathComponent("fusion_mux_\(UUID().uuidString).mp4")
        NSLog("[离线合成] 音轨位移 %.0fms，成片 %.2fs / 音轨可用 %.2fs",
              (shiftUs / 1000), CMTimeGetSeconds(CMTime(value: totalUs, timescale: 1_000_000)),
              CMTimeGetSeconds(usable))

        // ★ 0.5.2：Passthrough 导出对「音轨不从 0 开始」的排版不一定成功，
        //   而真机上眼镜的麦克风要 3.5 秒才起播，位移恒为几秒 —— 这一步失败的代价
        //   就是整条片子没声音，跟没做这个功能一样。所以先试 passthrough（视频不重编码），
        //   失败立刻退到最高质量重编一遍。640×480 的素材重编码代价很小。
        let presets = needsGain
            ? [AVAssetExportPresetHighestQuality]
            : [AVAssetExportPresetPassthrough, AVAssetExportPresetHighestQuality]

        for (i, usePreset) in presets.enumerated() {
            guard let export = AVAssetExportSession(asset: comp, presetName: usePreset) else {
                NSLog("[离线合成] 无法创建导出会话（preset=%@），换下一个", usePreset)
                continue
            }
            let target = i == 0 ? out
                : videoURL.deletingLastPathComponent()
                    .appendingPathComponent("fusion_mux_\(UUID().uuidString).mp4")
            export.outputURL = target
            export.outputFileType = .mp4
            export.shouldOptimizeForNetworkUse = false
            if needsGain { export.audioMix = mix }

            let sem = DispatchSemaphore(value: 0)
            export.exportAsynchronously { sem.signal() }
            sem.wait()
            if export.status == .completed {
                NSLog("[离线合成] 音轨已并入（volume=%.2f, preset=%@）", volume, usePreset)
                return target
            }
            NSLog("[离线合成] 音轨合并导出失败（preset=%@）: status=%ld %@",
                  usePreset, export.status.rawValue,
                  export.error?.localizedDescription ?? "未知")
        }
        return nil
    }
}
