//
//  ADBSyncPuller.swift
//  FusionRecorder
//
//  ADB `sync:` 服务的 RECV（拉取）实现 —— 0.4.0 离线录制架构专用。
//
//  字节规格来自 AOSP packages/modules/adb/SYNC.TXT：
//   · 客户端发 RECV + 4 字节长度 + "<远端路径>\0"（长度含结尾 NUL）
//   · 设备回 DENT（mode/size/mtime，12 字节）+ 若干 DATA 块 + OKAY
//   · 失败时回 FAIL + 错误消息
//
//  与 ADBSyncPusher 一样是纯逻辑、无网络依赖，便于离线自测。
//  所有帧都包在 ADB WRTE 里，由 ADBClient 负责拆包/组包。
//

import Foundation

enum ADBSyncPullError: Error, LocalizedError {
    case rejected(String)
    case timeout
    case emptyFile(String)

    var errorDescription: String? {
        switch self {
        case .rejected(let message): return "设备拒绝拉取：\(message)"
        case .timeout: return "拉取超时"
        case .emptyFile(let path): return "远端文件为空：\(path)"
        }
    }
}

/// sync RECV 响应解析后的一条事件。
enum ADBSyncPullEvent {
    case dent(size: Int)      // DENT：文件元信息，size 用于进度条
    case data(Data)           // DATA：文件字节块
    case done                 // OKAY：传输完成
    case failed(String)       // FAIL：设备拒绝
}

struct ADBSyncPuller {

    /// 构造要写进 sync 流的 RECV 请求。路径以 NUL 结尾（AOSP 长度含 NUL）。
    static func recvFrame(path: String) -> Data {
        var payload = Data(path.utf8)
        payload.append(0)
        return syncFrame("RECV", payload: payload)
    }

    /// 从累积缓冲区解析尽量多的完整响应帧。
    /// - returns: events 与已消费的字节数；不足一帧的部分留在缓冲区等下一次。
    static func parseResponses(_ buffer: Data) -> (events: [ADBSyncPullEvent], consumed: Int) {
        var events: [ADBSyncPullEvent] = []
        var offset = 0

        while buffer.count - offset >= 8 {
            let id = String(decoding: buffer[offset..<(offset + 4)], as: UTF8.self)
            let length = Int(leValue(buffer, at: offset + 4))
            guard buffer.count - offset >= 8 + length else { break }
            let payload = buffer[(offset + 8)..<(offset + 8 + length)]

            switch id {
            case "DENT":
                // mode(4) + size(4) + mtime(4)，小端；部分 adbd 只给 12 字节
                if payload.count >= 8 {
                    events.append(.dent(size: Int(leValue(payload, at: 4))))
                }
            case "DATA":
                events.append(.data(Data(payload)))
            case "OKAY", "DONE":
                // ★ 关键：RECV 的结束帧是 DONE（AOSP file_sync_service do_recv 末尾
                // 发 ID_DONE），不是 OKAY —— OKAY 只用于 SEND(push) 的应答。
                // 两种都认，避免不同 adbd 实现差异导致 pull 永远等不到结束。
                events.append(.done)
            case "FAIL":
                events.append(.failed(String(decoding: payload, as: UTF8.self)))
            default:
                break   // 未知帧忽略，继续往后解析
            }
            offset += 8 + length
        }
        return (events, offset)
    }

    static func syncFrame(_ id: String, payload: Data) -> Data {
        precondition(id.utf8.count == 4)
        var frame = Data(id.utf8)
        frame.append(contentsOf: le32(UInt32(payload.count)))
        frame.append(payload)
        return frame
    }

    private static func le32(_ value: UInt32) -> [UInt8] {
        [UInt8(value & 0xff), UInt8((value >> 8) & 0xff),
         UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff)]
    }

    /// 从 Data 的指定相对偏移读一个小端 u32。
    /// 注意：Data 切片（`buffer[a..<b]`）保留父容器的 Index，`payload[4..<8]`
    /// 并不是「payload 的第 4 字节」，必须用 startIndex 做基准重新换算。
    private static func leValue(_ data: Data, at offset: Int) -> UInt32 {
        let base = data.startIndex + offset
        let b = [UInt8](data[base..<(base + 4)])
        return UInt32(b[0]) | (UInt32(b[1]) << 8)
            | (UInt32(b[2]) << 16) | (UInt32(b[3]) << 24)
    }
}
