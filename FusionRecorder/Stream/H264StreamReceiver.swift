//
//  H264StreamReceiver.swift
//  FusionRecorder
//
//  一路裸 TCP H264 流接收。眼镜端用 MediaCodec 硬编后直接 write(socket)，
//  输出是 Annex-B（00 00 00 01 / 00 00 01 起始码）裸流，没有容器、没有 pts。
//
//  v0.1 已实现：TCP 长连接、半包/粘包处理、按起始码切出完整 NAL。
//  TODO(v0.2)：每个 NAL 前带上设备端 pts（交接包 §7 待办 1），交给解码器。
//

import Foundation
import Network

final class H264StreamReceiver {
    private let connection: NWConnection
    private let queue: DispatchQueue
    private let onNAL: (Data) -> Void
    private let onState: (String) -> Void
    private var buffer = Data()
    private var running = false

    init(host: String,
         port: UInt16,
         label: String,
         onNAL: @escaping (Data) -> Void,
         onState: @escaping (String) -> Void) {
        let nwPort = NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: 9114)!
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
        connection = NWConnection(to: endpoint, using: .tcp)
        queue = DispatchQueue(label: "com.lath.fusionrecorder.stream.\(label)")
        self.onNAL = onNAL
        self.onState = onState
    }

    func start() {
        guard !running else { return }
        running = true
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.onState("已连接，等待 H264 数据")
                self.receiveLoop()
            case .waiting(let error):
                self.onState("等待网络: \(error.localizedDescription)")
            case .failed(let error):
                self.onState("连接失败: \(error.localizedDescription)")
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    func stop() {
        running = false
        connection.cancel()
    }

    private func receiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { [weak self] data, _, isComplete, error in
            guard let self = self, self.running else { return }
            if let error = error {
                self.onState("接收错误: \(error.localizedDescription)")
                return
            }
            if let data = data {
                self.queue.async {
                    self.buffer.append(data)
                    self.drainNALs()
                }
            }
            if !isComplete { self.receiveLoop() }
        }
    }

    /// Annex-B 拆包：只有两个起始码之间的 NAL 才算完整，末尾不完整的留到下一次。
    private func drainNALs() {
        var starts: [Int] = []
        var i = 0
        let count = buffer.count
        while i + 3 <= count {
            let b0 = buffer[i]
            let b1 = buffer[i + 1]
            let b2 = buffer[i + 2]
            if b0 == 0 && b1 == 0 && b2 == 1 {
                starts.append(i)
                i += 3
            } else if i + 4 <= count && b0 == 0 && b1 == 0 && b2 == 0 && buffer[i + 3] == 1 {
                starts.append(i)
                i += 4
            } else {
                i += 1
            }
        }

        guard starts.count >= 2 else { return }

        for index in 0..<(starts.count - 1) {
            let from = starts[index]
            let to = starts[index + 1]
            let prefixLength = (buffer[from + 2] == 0) ? 4 : 3
            let nal = Data(buffer[(from + prefixLength)..<to])
            if !nal.isEmpty { onNAL(nal) }
        }

        buffer.removeSubrange(0..<starts[starts.count - 1])
    }
}
