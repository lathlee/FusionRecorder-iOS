//
//  H264StreamReceiver.swift
//  FusionRecorder
//
//  一路裸 TCP H264 流【客户端】接收：iPhone 主动连眼镜的 9114/9115。
//  用于手动「从眼镜抓两帧」——这时眼镜端是 server。
//  全自动部署走 H264StreamListener（采集端主动连 iPhone），方向相反、两条路径并存。
//
//  Annex-B 拆 NAL 复用 H264NALSplitter 单一真源（与 Listener 一致）。
//

import Foundation
import Network

final class H264StreamReceiver {
    private let connection: NWConnection
    private let queue: DispatchQueue
    private let splitter = H264NALSplitter()
    private let onNAL: (Data) -> Void
    private let onState: (String) -> Void
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
                    self.splitter.feed(data, onNAL: self.onNAL)
                }
            }
            if !isComplete { self.receiveLoop() }
        }
    }
}
