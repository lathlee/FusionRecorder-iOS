//
//  FusionPtsParser.swift
//  FusionRecorder
//
//  采集端 v0.1.0 起在每帧前插一条 SEI pts NAL（H.264 type 6 /
//  user_data_unregistered），本类负责解析它，见 FusionRecorder-Android/PROTOCOL.md。
//
//  这是 Android 端 PtsSei.java 与 tools/stream_probe.py 的 Swift 等价实现，
//  三份实现的字节逻辑完全一致，且已被 Java 565 条 + Python 30 条断言验证。
//
//  兼容性：老裸流没有 SEI → parse 返回 nil → 调用方退回「到达顺序」近似时间轴，
//  不会崩、不会解码失败（H264FrameDecoder 原本就把 type 6 当 default 忽略）。
//

import Foundation

struct FusionPTS {
    let ptsUs: Int64
    let streamId: Int      // 1 = 屏幕 9114 / 2 = 相机 9115
    let seq: Int32
    let isHeartbeat: Bool
}

enum FusionPtsParser {

    private static let uuid: [UInt8] = Array("FUSIONPTS1".utf8) + [0, 0, 0, 0, 0, 0]
    private static let heartbeatFlag: Int32 = Int32(bitPattern: 0x80000000)

    /// 解析一条 SEI NAL（H264StreamReceiver 已剥离起始码，nal[0] 是 NAL header）。
    /// 不是本协议返回 nil。
    static func parse(_ nal: Data) -> FusionPTS? {
        let bytes = [UInt8](nal)
        guard let first = bytes.first, (first & 0x1f) == 6 else { return nil }

        // EBSP 逆转义：连续两个 0x00 之后的那个 0x03 是转义字节，直接丢弃。
        var rbsp: [UInt8] = []
        rbsp.reserveCapacity(bytes.count)
        var zeros = 0
        for v in bytes.dropFirst() {                 // 跳过 NAL header
            if zeros >= 2 && v == 3 {
                zeros = 0
                continue
            }
            rbsp.append(v)
            zeros = (v == 0) ? zeros + 1 : 0
        }
        // payloadType(5) + payloadSize(29) + payload + trailing(0x80) 至少 32 字节
        guard rbsp.count >= 2 + 29 + 1 else { return nil }
        guard rbsp[0] == 0x05, rbsp[1] == 29 else { return nil }

        var p = 2
        guard p + 16 <= rbsp.count else { return nil }
        for i in 0..<16 where rbsp[p + i] != uuid[i] { return nil }
        p += 16

        guard p + 8 <= rbsp.count else { return nil }
        var pts: UInt64 = 0
        for _ in 0..<8 {
            pts = (pts << 8) | UInt64(rbsp[p])
            p += 1
        }
        guard p < rbsp.count else { return nil }
        let sid = Int(rbsp[p])
        p += 1
        guard sid == 1 || sid == 2 else { return nil }

        guard p + 4 <= rbsp.count else { return nil }
        let seqBits: Int32 = (Int32(rbsp[p]) << 24) | (Int32(rbsp[p + 1]) << 16)
            | (Int32(rbsp[p + 2]) << 8) | Int32(rbsp[p + 3])

        return FusionPTS(
            ptsUs: Int64(bitPattern: pts),
            streamId: sid,
            seq: seqBits & heartbeatFlag == 0 ? seqBits : (seqBits & ~heartbeatFlag),
            isHeartbeat: (seqBits & heartbeatFlag) != 0
        )
    }
}
