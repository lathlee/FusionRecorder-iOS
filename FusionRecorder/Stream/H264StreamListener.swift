//
//  H264StreamListener.swift
//  FusionRecorder
//
//  TCP 监听端：采集端（眼镜）主动连 iPhone 的 9114/9115，iPhone 这里必须监听。
//  这与 H264StreamReceiver（客户端，iPhone 主动连眼镜）方向相反——
//  全自动部署用 Listener，手动抓帧仍可用 Receiver，两条路径并存互不破坏。
//
//  收到字节后复用与 Receiver 完全相同的 Annex-B 拆 NAL 逻辑（半包/粘包）。
//  ★ 拆 NAL 逻辑抽到 H264NALSplitter 单一真源，Receiver / Listener 都调它，
//    避免两处实现漂移。
//

import Foundation
import Network

/// Annex-B 拆 NAL 的唯一真源（逐字节等价原 H264StreamReceiver.drainNALs）。
final class H264NALSplitter {
    private var buffer = Data()

    /// 喂入网络字节，回调每个完整 NAL（已剥离起始码）。
    func feed(_ chunk: Data, onNAL: (Data) -> Void) {
        buffer.append(chunk)
        var starts: [Int] = []
        var i = 0
        let count = buffer.count
        while i + 3 <= count {
            let b0 = buffer[i], b1 = buffer[i + 1], b2 = buffer[i + 2]
            if b0 == 0 && b1 == 0 && b2 == 1 {
                starts.append(i); i += 3
            } else if i + 4 <= count && b0 == 0 && b1 == 0 && b2 == 0 && buffer[i + 3] == 1 {
                starts.append(i); i += 4
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

    func reset() { buffer.removeAll() }
}

final class H264StreamListener {
    private let listener: NWListener
    private let queue: DispatchQueue
    private let splitter = H264NALSplitter()
    private let onNAL: (Data) -> Void
    private let onState: (String) -> Void
    private var connection: NWConnection?
    private var running = false

    init(port: UInt16, label: String,
         onNAL: @escaping (Data) -> Void,
         onState: @escaping (String) -> Void) {
        let nwPort = NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: 9114)!
        listener = try! NWListener(using: .tcp, on: nwPort)
        queue = DispatchQueue(label: "com.lath.fusionrecorder.listen.\(label)")
        self.onNAL = onNAL
        self.onState = onState
    }

    func start() {
        guard !running else { return }
        running = true
        listener.newConnectionHandler = { [weak self] connection in
            guard let self = self else { return }
            self.connection?.cancel()
            self.connection = connection
            self.splitter.reset()
            connection.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .ready:
                    self.onState("眼镜已接入，等待 H264 数据")
                    self.receiveLoop(on: connection)
                case .failed(let error):
                    self.onState("连接断开: \(error.localizedDescription)")
                default:
                    break
                }
            }
            connection.start(queue: self.queue)
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready: self.onState("监听已就绪")
            case .failed(let error): self.onState("监听失败: \(error.localizedDescription)")
            default: break
            }
        }
        listener.start(queue: queue)
    }

    func stop() {
        running = false
        connection?.cancel()
        connection = nil
        listener.cancel()
    }

    private func receiveLoop(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { [weak self] data, _, isComplete, error in
            guard let self = self, self.running else { return }
            if let error = error {
                self.onState("接收错误: \(error.localizedDescription)")
                return
            }
            if let data = data {
                self.queue.async {
                    self.splitter.feed(data, onNAL: self.onNAL)
                }
            }
            if !isComplete { self.receiveLoop(on: connection) }
        }
    }
}
