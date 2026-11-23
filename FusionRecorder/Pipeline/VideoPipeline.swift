//
//  VideoPipeline.swift
//  FusionRecorder
//
//  录制侧管线。**不再有第二套合成算法**：录制每一帧都委托给
//  FusionCompositor.render，参数对象与预览共用同一个 FusionParams。
//
//  ★ 这就是「预览里调 OK，成片里不会变样」的代码级保证：
//      预览  ── FusionParams ──> FusionCompositor.render ──> 预览画面
//      录制  ── FusionParams ──> FusionCompositor.render ──> 写入帧
//    两条路径只有输入帧的来源不同（已保存的截图 vs 实时流帧），
//    画布尺寸、参数、像素运算完全相同。
//
//  v0.2：MovieWriter 用 AVAssetWriter + VT 的 PixelBufferAdaptor 逐帧写 mp4，
//  时间轴用设备端真实 pts（微秒）；成片完成后写相册。
//  写入的仍是 RecordingCompositor.compose 的输出，不在这里做任何效果调整。
//

import Foundation
import AVFoundation
import CoreMedia
import CoreVideo
import CoreGraphics
import VideoToolbox
import Photos
import UIKit

enum PipelineError: Error, LocalizedError {
    case invalidState(String)
    case writerSetupFailed(String)
    case appendFailed(String)
    case finishFailed(String)
    case photoSaveFailed(String)
    case noFrames

    var errorDescription: String? {
        switch self {
        case .invalidState(let s): return "录制状态错误：\(s)"
        case .writerSetupFailed(let s): return "编码器初始化失败：\(s)"
        case .appendFailed(let s): return "写入帧失败：\(s)"
        case .finishFailed(let s): return "封装成片失败：\(s)"
        case .photoSaveFailed(let s): return "保存到相册失败：\(s)"
        case .noFrames: return "没有可写入的帧"
        }
    }
}

/// 录制侧合成器：只做「转发到唯一合成入口」这一件事。
final class RecordingCompositor {
    private var params: FusionParams
    private let lock = NSLock()

    init(params: FusionParams) {
        self.params = params
    }

    /// 参数在预览里被拖动时由 UI 同步过来，保证录制用的是同一组数值
    func update(_ newParams: FusionParams) {
        lock.lock()
        params = newParams
        lock.unlock()
    }

    var currentParams: FusionParams {
        lock.lock()
        defer { lock.unlock() }
        return params
    }

    /// 录制时的每一帧调用它。返回值就是要写进视频的那一帧。
    func compose(screen: CGImage, camera: CGImage) -> CGImage? {
        let p = currentParams
        return FusionCompositor.render(screen: screen, camera: camera, params: p)
    }
}

/// 合成帧 → H264 → mp4 → 相册。
///
/// 输入：CGImage（由 RecordingCompositor.compose 产出）+ 微秒 pts。
/// 输出：保存到相册的 mp4。
///
/// 关键设计：
///  · 用 AVAssetWriter + PixelBufferAdaptor，编码参数固定 H264 / yuv420p；
///  · 时间轴用设备端真实 pts（公共单调时钟微秒），首帧归零，timescale=1_000_000；
///  · 所有写操作在私有串行队列，避免 AVAssetWriter 的线程约束；
///  · 这里绝不修改画面——合成只在 FusionCompositor 里发生一次。
final class MovieWriter {

    private enum State {
        case idle
        case writing
        case finishing
        case finished
    }

    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var state: State = .idle
    private let queue = DispatchQueue(label: "com.lath.fusionrecorder.moviewriter")
    private var outputURL: URL?
    private var firstPTS: Int64?
    private var frameCount = 0
    private var lastPTS: Int64 = -1

    /// 合成画布尺寸（由 FusionParams 决定， = 成片分辨率）
    private let width: Int
    private let height: Int

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    /// 开始一次录制。outputURL 由调用方给（临时目录里的 .mp4）。
    func start(outputURL: URL) throws {
        guard state == .idle else {
            throw PipelineError.invalidState("start 只能在 idle 调用，当前 \(state)")
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: outputURL.path) {
            try? fileManager.removeItem(at: outputURL)
        }

        guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            throw PipelineError.writerSetupFailed("AVAssetWriter(outputURL:) 返回 nil")
        }

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 4_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ] as [String: Any]
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        writerInput.expectsMediaDataInRealTime = true

        let pixelAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        let pixelAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: pixelAttrs)

        guard assetWriter.canAdd(writerInput) else {
            throw PipelineError.writerSetupFailed("canAdd(input) == false")
        }
        assetWriter.add(writerInput)

        writer = assetWriter
        input = writerInput
        adaptor = pixelAdaptor
        self.outputURL = outputURL
        firstPTS = nil
        frameCount = 0
        lastPTS = -1

        assetWriter.startWriting()
        // 首帧的实际 pts 要等第一帧到了才知道，先用 0 起会话；
        // 写入帧时统一减去 firstPTS，保证时间轴从 0 开始且单调递增。
        assetWriter.startSession(atSourceTime: .zero)
        state = .writing
    }

    /// 写一帧。presentationTimeUs 是设备端单调时钟微秒（绝对路径）。
    /// 调用方必须按时间顺序调用（v0.2 的帧队列已按 pts 排好序）。
    func append(frame: CGImage, presentationTimeUs: Int64) throws {
        guard state == .writing else {
            throw PipelineError.invalidState("append 时状态 \(state)")
        }
        guard presentationTimeUs >= lastPTS else {
            throw PipelineError.invalidState("pts 非递增：\(presentationTimeUs) <= \(lastPTS)")
        }
        lastPTS = presentationTimeUs
        if firstPTS == nil { firstPTS = presentationTimeUs }

        guard let buffer = Self.pixelBuffer(from: frame, width: width, height: height) else {
            throw PipelineError.appendFailed("CGImage → CVPixelBuffer 失败")
        }
        let pts = presentationTimeUs - (firstPTS ?? presentationTimeUs)
        let time = CMTime(value: pts, timescale: 1_000_000)

        // AVAssetWriterInput 要求串行 append；这里同步等每次写完再返回。
        let error = queue.sync { () -> Error? in
            guard let input = input, let adaptor = adaptor else {
                return PipelineError.invalidState("writer input 丢失")
            }
            // isReadyForMoreMediaData 为 false 时短暂等待，避免丢帧
            var waited = 0
            while !input.isReadyForMoreMediaData && waited < 100 {
                Thread.sleep(forTimeInterval: 0.002)
                waited += 1
            }
            guard input.isReadyForMoreMediaData else {
                return PipelineError.appendFailed("input 长时间 not ready")
            }
            guard adaptor.append(buffer, withPresentationTime: time) else {
                return PipelineError.appendFailed("adaptor.append 返回 false")
            }
            return nil
        }
        if let error = error { throw error }
        frameCount += 1
    }

    /// 结束录制：标记 input finished → finishWriting → 保存到相册。
    func finish(completion: @escaping (Result<URL, Error>) -> Void) {
        finishWithoutSaving { result in
            switch result {
            case .success(let url):
                Self.saveToAlbum(url: url, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 只把文件写完，**不**存相册。
    ///
    /// 0.5.0 需要它：离线合成先在临时目录写出一版「只有画面」的 mp4，
    /// 再把眼镜录的音轨并进去，最后才存相册。中间那一版不能出现在相册里。
    func finishWithoutSaving(completion: @escaping (Result<URL, Error>) -> Void) {
        guard state == .writing else {
            completion(.failure(PipelineError.invalidState("finish 时状态 \(state)")))
            return
        }
        guard frameCount > 0 else {
            completion(.failure(PipelineError.noFrames))
            return
        }
        state = .finishing
        input?.markAsFinished()

        writer?.finishWriting { [weak self] in
            guard let self = self else { return }
            let writerError = self.writer?.error
            if let writerError = writerError {
                completion(.failure(PipelineError.finishFailed(writerError.localizedDescription)))
                return
            }
            guard let url = self.outputURL else {
                completion(.failure(PipelineError.finishFailed("输出 URL 丢失")))
                return
            }
            self.state = .finished
            completion(.success(url))
        }
    }

    /// 放弃录制（停止时还没开始写或出错）
    func cancel() {
        queue.sync {
            if state == .writing {
                writer?.cancelWriting()
            }
            state = .finished
            writer = nil
            input = nil
            adaptor = nil
        }
    }

    var writtenFrames: Int { frameCount }

    // MARK: - 私有

    /// 把成片存进相册（合成与存盘分开后，这一步由 OfflineCompositor 显式调用）。
    static func saveToAlbum(url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { success, error in
            if success {
                completion(.success(url))
            } else {
                completion(.failure(PipelineError.photoSaveFailed(
                    error?.localizedDescription ?? "未知错误")))
            }
        }
    }

    /// CGImage → CVPixelBuffer（BGRA，预乘 alpha，与合成器输出一致）。
    static func pixelBuffer(from image: CGImage, width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue as Any,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue as Any
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}
