//
//  VideoPipeline.swift
//  FusionRecorder
//
//  视频管线骨架，对应交接包 §7 待办 2：
//    VideoToolbox 双路解码 → Metal 合成 → VideoToolbox 编码 → AVAssetWriter 写相册
//
//  v0.1 只落地类型与生命周期，把编译链路跑通；
//  真实实现（含 alpha 0.55 / 加色混合 / 边缘 fade / 透视 skew 复刻 CompositorRenderer）
//  在 v0.2 接真机联调时补齐，不在这里假装已实现。
//

import Foundation
import AVFoundation
import CoreMedia
import CoreVideo
import VideoToolbox
import Metal
import Photos

enum PipelineError: Error, LocalizedError {
    case notImplemented

    var errorDescription: String? {
        return "视频管线待实现（v0.2）"
    }
}

/// 一路 H264 → CVPixelBuffer
final class H264Decoder {
    private var session: VTDecompressionSession?
    private var formatDescription: CMVideoFormatDescription?

    func configure(sps: Data, pps: Data) {
        // TODO: CMVideoFormatDescriptionCreateFromH264ParameterSets
        //       + VTDecompressionSessionCreate（输出 BGRA / NV12 像素格式）
        _ = sps
        _ = pps
    }

    func decode(nal: Data, presentationTime: CMTime) {
        // TODO: CMBlockBuffer → CMSampleBuffer → VTDecompressionSessionDecodeFrame
        _ = nal
        _ = presentationTime
    }

    func invalidate() {
        if let session = session {
            VTDecompressionSessionInvalidate(session)
            self.session = nil
        }
        formatDescription = nil
    }
}

/// 屏幕流（中心半透明面板）叠加到相机流（背景）
final class MetalCompositor {
    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?

    init() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
    }

    var isAvailable: Bool { device != nil }

    func compose(screen: CVPixelBuffer, camera: CVPixelBuffer) -> CVPixelBuffer? {
        // TODO: 复刻 CompositorRenderer（alpha 0.55 / 加色混合 / 边缘 fade / 透视 skew）
        _ = commandQueue
        _ = screen
        _ = camera
        return nil
    }
}

/// 合成后的画面 → H264
final class H264Encoder {
    private var session: VTCompressionSession?

    func configure(width: Int32, height: Int32) {
        // TODO: VTCompressionSessionCreate(kCMVideoCodecType_H264) + 实时/低延迟设置
        _ = width
        _ = height
    }

    func encode(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        // TODO: VTCompressionSessionEncodeFrame → CMSampleBuffer
        _ = pixelBuffer
        _ = presentationTime
    }

    func invalidate() {
        if let session = session {
            VTCompressionSessionInvalidate(session)
            self.session = nil
        }
    }
}

/// H264 → mp4 → 相册
final class MovieWriter {
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?

    func start(outputURL: URL, width: Int, height: Int) throws {
        // TODO: AVAssetWriter + AVAssetWriterInput(H264) + startWriting/startSession
        _ = outputURL
        _ = width
        _ = height
    }

    func append(sampleBuffer: CMSampleBuffer) {
        // TODO: input?.append(sampleBuffer)
        _ = sampleBuffer
    }

    func finish(completion: @escaping (Result<URL, Error>) -> Void) {
        // TODO: finishWriting → PHPhotoLibrary.shared().performChanges 保存到相册
        _ = writer
        _ = input
        completion(.failure(PipelineError.notImplemented))
    }
}
