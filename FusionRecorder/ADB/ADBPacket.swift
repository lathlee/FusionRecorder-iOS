//
//  ADBPacket.swift
//  FusionRecorder
//
//  ADB 协议帧：24 字节头 + payload，小端。
//  command 是 4 个 ASCII 字符按内存顺序拼成的 UInt32（对应 ADB 源码的 A_CNXN 等常量）。
//

import Foundation

struct ADBPacket {
    let command: UInt32
    let arg0: UInt32
    let arg1: UInt32
    let payload: Data

    static let CNXN: UInt32 = 0x4e584e43
    static let AUTH: UInt32 = 0x48545541
    static let OPEN: UInt32 = 0x4e45504f
    static let OKAY: UInt32 = 0x59414b4f
    static let WRTE: UInt32 = 0x45545257
    static let CLSE: UInt32 = 0x45534c43

    static let authToken: UInt32 = 1
    static let authSignature: UInt32 = 2
    static let authPublicKey: UInt32 = 3

    static let systemIdentity = "host::features=shell_v2,cmd,stat_v2,ls_v2;"

    static func commandWord(_ text: String) -> UInt32 {
        var value: UInt32 = 0
        for (index, byte) in text.utf8.prefix(4).enumerated() {
            value |= UInt32(byte) << UInt32(8 * index)
        }
        return value
    }

    init(command: UInt32, arg0: UInt32, arg1: UInt32, payload: Data = Data()) {
        self.command = command
        self.arg0 = arg0
        self.arg1 = arg1
        self.payload = payload
    }

    func encoded() -> Data {
        var data = Data()
        data.append(contentsOf: littleEndianBytes(command))
        data.append(contentsOf: littleEndianBytes(arg0))
        data.append(contentsOf: littleEndianBytes(arg1))

        var checksum: UInt32 = 0
        for byte in payload { checksum = checksum &+ UInt32(byte) }

        data.append(contentsOf: littleEndianBytes(UInt32(payload.count)))
        data.append(contentsOf: littleEndianBytes(checksum))
        data.append(contentsOf: littleEndianBytes(command ^ 0xffffffff))
        data.append(payload)
        return data
    }

    private func littleEndianBytes(_ value: UInt32) -> [UInt8] {
        return [
            UInt8(value & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 24) & 0xff)
        ]
    }

    /// 从接收缓冲区头部解析一帧；不足一整帧返回 nil，调用方继续收数据。
    static func parse(_ buffer: Data) -> (packet: ADBPacket, consumed: Int)? {
        guard buffer.count >= 24 else { return nil }

        func u32(_ offset: Int) -> UInt32 {
            let bytes = [UInt8](buffer[offset..<(offset + 4)])
            return UInt32(bytes[0])
                | (UInt32(bytes[1]) << 8)
                | (UInt32(bytes[2]) << 16)
                | (UInt32(bytes[3]) << 24)
        }

        let command = u32(0)
        let arg0 = u32(4)
        let arg1 = u32(8)
        let length = Int(u32(12))
        guard buffer.count >= 24 + length else { return nil }
        let payload = Data(buffer[24..<(24 + length)])
        return (ADBPacket(command: command, arg0: arg0, arg1: arg1, payload: payload), 24 + length)
    }
}
