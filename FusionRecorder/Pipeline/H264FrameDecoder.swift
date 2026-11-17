//
//  H264FrameDecoder.swift
//  FusionRecorder
//
//  「从眼镜抓帧」用的真实解码：把 9114 / 9115 两路裸 TCP Annex-B H264
//  里的 SPS/PPS/IDR 交给 VideoToolbox，解出一帧 CVPixelBuffer 再转 CGImage。
//
//  录制逐帧管线（v0.2）复用本类，避免预览抓帧和正式录制走出两套解码语义。
//  注：裸流暂时没有 pts（交接包 §7 待办 1），这里只按到达顺序取帧，
//      双路各取一帧用于标定参数；正式录制需补 pts 做对齐。
//

import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo
import CoreGraphics
import CoreImage

final class H264FrameDecoder {

    private var sps: Data?
    private var pps: Data?
    private var formatDescription: CMVideoFormatDescription?
    private var session: VTDecompressionSession?
    private var latest: CGImage?
    private var pendingPTS: FusionPTS?
    private let lock = NSLock()
    private let ciContext = CIContext()

    /// v0.1 兼容接口：返回当前已解出的最新画面（拿到 IDR 前为 nil）。
    /// 抓帧（captureFrames）仍用它；新代码请用 feedWithPTS 拿真实时间戳。
    func feed(_ nal: Data) -> CGImage? {
        return feedWithPTS(nal)?.image
    }

    /// v0.2 录制接口：解析 SEI pts，返回「帧 + 设备端单调时钟微秒」。
    /// 同一 NAL 里的 SEI 一定在 VCL 前到达；心跳 SEI 后没有画面帧，
    /// 只更新 pendingPTS 而不返回帧。老裸流（无 SEI）时 ptsUs 取到达时刻近似。
    func feedWithPTS(_ nal: Data) -> (image: CGImage, ptsUs: Int64)? {
        guard let header = nal.first else { return nil }
        switch header & 0x1f {
        case 6:                       // SEI：解析 pts（v0.1 走 default 忽略，兼容）
            if let parsed = FusionPtsParser.parse(nal) {
                lock.lock()
                pendingPTS = parsed
                lock.unlock()
            }
            return nil
        case 7:                       // SPS
            sps = nal
        case 8:                       // PPS
            pps = nal
        case 5, 1:                    // IDR / non-IDR slice
            if session == nil { configure() }
            if session != nil { decode(nal) }
        default:
            break
        }
        lock.lock()
        defer { lock.unlock() }
        guard let image = latest else { return nil }
        let pts = pendingPTS?.ptsUs ?? Int64(Date().timeIntervalSince1970 * 1_000_000)
        pendingPTS = nil   // 一个 pts 绑定一个画面帧，不串到下一帧
        return (image, pts)
    }

    var decodedFrame: CGImage? {
        lock.lock()
        defer { lock.unlock() }
        return latest
    }

    func invalidate() {
        if let session = session {
            VTDecompressionSessionWaitForAsynchronousFrames(session)
            VTDecompressionSessionInvalidate(session)
            self.session = nil
        }
        formatDescription = nil
        sps = nil
        pps = nil
        lock.lock()
        latest = nil
        pendingPTS = nil
        lock.unlock()
    }

    deinit {
        if let session = session {
            VTDecompressionSessionInvalidate(session)
        }
    }

    // MARK: - VideoToolbox 会话

    private func configure() {
        guard let sps = sps, let pps = pps else { return }

        var spsBytes = [UInt8](sps)
        var ppsBytes = [UInt8](pps)
        var sizes = [sps.count, pps.count]
        var fmt: CMVideoFormatDescription?

        let status: OSStatus = spsBytes.withUnsafeMutableBufferPointer { spsBuf -> OSStatus in
            ppsBytes.withUnsafeMutableBufferPointer { ppsBuf -> OSStatus in
                guard let s0 = spsBuf.baseAddress, let p0 = ppsBuf.baseAddress else {
                    return -1
                }
                var pointers: [UnsafePointer<UInt8>] = [
                    UnsafePointer<UInt8>(s0),
                    UnsafePointer<UInt8>(p0)
                ]
                return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: 2,
                    parameterSetPointers: &pointers,
                    parameterSetSizes: &sizes,
                    nalUnitHeaderLength: 4,
                    formatDescriptionOut: &fmt)
            }
        }
        guard status == noErr, let fmt = fmt else { return }
        formatDescription = fmt

        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA)
        ]

        let callback: VTDecompressionOutputCallback = { refCon, _, decodeStatus, _, imageBuffer, _, _ in
            guard decodeStatus == noErr, let imageBuffer = imageBuffer, let refCon = refCon else { return }
            let decoder = Unmanaged<H264FrameDecoder>.fromOpaque(refCon).takeUnretainedValue()
            decoder.onDecoded(imageBuffer)
        }
        var record = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: callback,
            decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque())

        var out: VTDecompressionSession?
        let result = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: fmt,
            decoderSpecification: nil,
            imageBufferAttributes: attributes as CFDictionary,
            outputCallback: &record,
            decompressionSessionOut: &out)
        guard result == noErr, let out = out else { return }
        session = out
    }

    private func decode(_ nal: Data) {
        guard let fmt = formatDescription, let session = session else { return }

        // Annex-B → AVCC：4 字节大端长度 + NAL
        var avcc = Data()
        var lengthBE = UInt32(nal.count).bigEndian
        withUnsafeBytes(of: &lengthBE) { avcc.append(contentsOf: $0) }
        avcc.append(nal)

        var bytes = [UInt8](avcc)
        var blockBuffer: CMBlockBuffer?
        let blockStatus = bytes.withUnsafeMutableBytes { raw -> OSStatus in
            CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: raw.baseAddress,
                blockLength: avcc.count,
                blockAllocator: kCFAllocatorNull,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: avcc.count,
                flags: 0,
                blockBufferOut: &blockBuffer)
        }
        guard blockStatus == kCMBlockBufferNoErr, let blockBuffer = blockBuffer else { return }

        var sampleBuffer: CMSampleBuffer?
        var sampleSize = avcc.count
        let sampleStatus = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: fmt,
            sampleCount: 1,
            sampleTimingEntryCount: 0,
            sampleTimingArray: nil,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer)
        guard sampleStatus == noErr, let sampleBuffer = sampleBuffer else { return }

        var infoFlags: VTDecodeInfoFlags = []
        _ = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: [],
            frameRefcon: nil,
            infoFlagsOut: &infoFlags)
        // iOS SDK 没有 WaitForSynchronousFrames；用 WaitForAsynchronousFrames
        // 等解码回调落地再返回，保证 latest 已就绪（抓帧是低频操作，可阻塞）
        _ = VTDecompressionSessionWaitForAsynchronousFrames(session)
    }

    private func onDecoded(_ buffer: CVImageBuffer) {
        let image = CIImage(cvImageBuffer: buffer)
        guard let cg = ciContext.createCGImage(image, from: image.extent) else { return }
        lock.lock()
        latest = cg
        lock.unlock()
    }
}
