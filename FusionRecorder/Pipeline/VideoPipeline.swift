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
//  v0.2 待办（交接包 §7）：双路 pts 对齐、VTCompressionSession 编码、
//  AVAssetWriter 写 mp4 到相册。这些补齐后，写入的仍是本类 compose 的输出，
//  不需要也不会重写合成逻辑。
//

import Foundation
import AVFoundation
import CoreMedia
import CoreVideo
import CoreGraphics
import VideoToolbox
import Photos

enum PipelineError: Error, LocalizedError {
    case notImplemented

    var errorDescription: String? {
        return "逐帧编码 / 写相册待实现（v0.2）；合成部分已完成且与预览同源"
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
/// v0.2 接入 VTCompressionSession + AVAssetWriter；输入必须是
/// RecordingCompositor.compose 的输出，不允许在这里再做一次「效果调整」。
final class MovieWriter {
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?

    func start(outputURL: URL, width: Int, height: Int) throws {
        _ = outputURL
        _ = width
        _ = height
        throw PipelineError.notImplemented
    }

    func append(frame: CGImage, presentationTime: CMTime) {
        _ = frame
        _ = presentationTime
    }

    func finish(completion: @escaping (Result<URL, Error>) -> Void) {
        _ = writer
        _ = input
        completion(.failure(PipelineError.notImplemented))
    }
}
