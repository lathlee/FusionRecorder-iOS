//
//  ADBSyncPusher.swift
//  FusionRecorder
//
//  ADB `sync:` 服务的字节构造与响应解析（纯逻辑，无网络依赖，便于离线自测）。
//
//  字节规格来自 AOSP packages/modules/adb/SYNC.TXT：
//   · 所有 sync 包 = 4 字节 ASCII ID + 4 字节小端 uint32 长度 + 长度个字节
//   · SEND 的 payload 是 "<远端路径>,<st_mode 十进制>"，如 /data/local/tmp/screen-push.jar,33188
//     （33188 = 0o100644；adbd 按十进制解析，写八进制 "644" 会得到不可读的文件）
//   · DATA 每块 ≤ 64 KiB，长度即块字节数
//   · DONE 的长度是文件 mtime（秒），设备只对 DONE 回 OKAY/FAIL
//
//  为什么不用 shell 的 `printf | base64 -d`：toybox 的 base64 在部分 ROM 上缺参数，
//  而 sync: 是 adbd 内核级服务，行为最稳定。这是 scrcpy 同款方案。
//

import Foundation

enum ADBSyncError: Error, LocalizedError {
    case rejected(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .rejected(let message): return "设备拒绝：\(message)"
        case .timeout: return "push 超时"
        }
    }
}

struct ADBSyncPusher {

    /// 单个文件分块适配 sync DATA（≤64 KiB）。返回将要写进 sync 流的完整字节。
    /// - parameters:
    ///   - path: 远端绝对路径
    ///   - mode: **完整的 st_mode，十进制**（含 S_IFREG）。adbd 用 `strtoul(..., 10)`
    ///     解析这个字段，所以必须传 33188（= 0o100644），不能传八进制串 "644"。
    ///     真机 16:31 事故：传 "644" 被当成十进制 644 → chmod 成 0o1204（`--w----r-T`），
    ///     文件只写不可读，`pm install` 直接报 `Error: Can't open file`。
    ///   - data: 文件内容
    ///   - mtime: 远端文件时间戳（秒）
    static func sendFrames(path: String, mode: UInt32 = 0o100644,
                           data: Data, mtime: UInt32) -> [Data] {
        var frames: [Data] = []
        let pathMode = "\(path),\(mode)"
        frames.append(syncFrame("SEND", payload: Data(pathMode.utf8)))

        let chunkSize = 60 * 1024          // 留余量，严格小于 64 KiB
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            frames.append(syncFrame("DATA", payload: data.subdata(in: offset..<end)))
            offset = end
        }
        // 空文件也要发一个 0 长度 DATA，符合 adb 客户端惯例
        if data.isEmpty { frames.append(syncFrame("DATA", payload: Data())) }

        var done = Data("DONE".utf8)
        done.append(contentsOf: le32(mtime))
        frames.append(done)
        return frames
    }

    /// sync 响应的三种结局
    enum Outcome {
        case ok                 // OKAY：设备确认写入完成
        case failed(String)      // FAIL：设备拒绝
        case ignored             // 其它帧（DATA/DENT…）：丢掉继续等
    }

    /// 解析 sync 响应。
    /// ★ 只有 OKAY 才算成功。老逻辑把「未知帧」也当成功，会在设备还没写完时
    /// 就回报 push 成功，随后 `pm install` 报 "Can't open file"（真机 16:31 复现）。
    static func parseResponse(_ buffer: Data) -> (outcome: Outcome, consumed: Int)? {
        guard buffer.count >= 8 else { return nil }
        let id = String(decoding: buffer.prefix(4), as: UTF8.self)
        let length = Int(leValue(buffer, at: 4))
        guard buffer.count >= 8 + length else { return nil }
        switch id {
        case "OKAY":
            return (.ok, 8 + length)
        case "FAIL":
            let message = String(decoding: buffer.dropFirst(8).prefix(length), as: UTF8.self)
            return (.failed(message), 8 + length)
        default:
            return (.ignored, 8 + length)
        }
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

    private static func leValue(_ data: Data, at offset: Int) -> UInt32 {
        let b = [UInt8](data[offset..<(offset + 4)])
        return UInt32(b[0]) | (UInt32(b[1]) << 8) | (UInt32(b[2]) << 16) | (UInt32(b[3]) << 24)
    }
}
