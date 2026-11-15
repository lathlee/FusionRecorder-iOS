//
//  ADBClient.swift
//  FusionRecorder
//
//  轻量 ADB client（无线 ADB 只用来启动采集 / push server / 保活，视频流不挤进 adb）。
//
//  v0.1 已实现：CNXN / AUTH / OPEN / WRTE / OKAY / CLSE 帧状态机、TCP 收发、shell。
//  TODO(v0.2)：RSA 密钥持久化 + AUTH_SIGNATURE 回复 token；首次连接改发
//              AUTH_PUBLICKEY 让眼镜弹「允许调试」。不同 ROM 的授权界面表现不同，
//              需真机联调后定，见交接包 §7 待办 2。
//

import Foundation
import Network
import Security

enum ADBError: Error, LocalizedError {
    case connectionFailed(String)
    case notConnected

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message): return message
        case .notConnected: return "ADB 连接尚未就绪"
        }
    }
}

final class ADBClient {
    /// 日志回传（UI 侧负责切主线程）
    var log: ((String) -> Void)?

    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.lath.fusionrecorder.adb")
    private var buffer = Data()
    private var isReady = false
    private var connectHandlers: [(Result<Void, Error>) -> Void] = []
    private var shellHandlers: [UInt32: (Result<String, Error>) -> Void] = [:]
    private var nextLocalId: UInt32 = 0x10000001
    private var privateKey: SecKey?

    init(host: String, port: UInt16 = 5555) {
        let nwPort = NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: 5555)!
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
        connection = NWConnection(to: endpoint, using: .tcp)
    }

    func connect(completion: @escaping (Result<Void, Error>) -> Void) {
        queue.sync { connectHandlers.append(completion) }

        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.queue.async { self.sendCNXN() }
                self.receiveLoop()
            case .failed(let error):
                self.failAll(ADBError.connectionFailed(error.localizedDescription))
            case .cancelled:
                self.failAll(ADBError.notConnected)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    func disconnect() {
        connection.cancel()
    }

    func shell(_ command: String, completion: @escaping (Result<String, Error>) -> Void) {
        queue.async {
            guard self.isReady else {
                completion(.failure(ADBError.notConnected))
                return
            }
            let localId = self.nextLocalId
            self.nextLocalId &+= 1
            self.shellHandlers[localId] = completion
            var payload = Data("shell:\(command)".utf8)
            payload.append(0)
            self.send(ADBPacket(command: ADBPacket.OPEN, arg0: localId, arg1: 0, payload: payload))
        }
    }

    /// 预先准备 RSA 密钥对（认证真正用起来在 v0.2）
    @discardableResult
    func ensureKeyPair() -> Bool {
        if privateKey != nil { return true }
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048
        ]
        var error: Unmanaged<CFError>?
        privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error)
        return privateKey != nil
    }

    // MARK: - 私有

    private func send(_ packet: ADBPacket) {
        let data = packet.encoded()
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.log?("发送失败: \(error.localizedDescription)")
            }
        })
    }

    private func sendCNXN() {
        var payload = Data(ADBPacket.systemIdentity.utf8)
        payload.append(0)
        // version = 0x01000000, maxdata = 1 MiB
        send(ADBPacket(command: ADBPacket.CNXN, arg0: 0x01000000, arg1: 0x00100000, payload: payload))
    }

    private func receiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let error = error {
                self.failAll(ADBError.connectionFailed(error.localizedDescription))
                return
            }
            if let data = data {
                self.queue.async {
                    self.buffer.append(data)
                    self.drainPackets()
                }
            }
            if !isComplete { self.receiveLoop() }
        }
    }

    private func drainPackets() {
        while let parsed = ADBPacket.parse(buffer) {
            buffer.removeSubrange(0..<parsed.consumed)
            handle(parsed.packet)
        }
    }

    private func handle(_ packet: ADBPacket) {
        switch packet.command {
        case ADBPacket.AUTH:
            guard packet.arg0 == ADBPacket.authToken else { return }
            handleAuthToken(packet.payload)

        case ADBPacket.CNXN:
            isReady = true
            log?("握手完成 (CNXN)")
            resolveConnect(.success(()))

        case ADBPacket.OKAY:
            log?("stream \(packet.arg1) 已就绪")

        case ADBPacket.WRTE:
            let localId = packet.arg1
            if let text = String(data: packet.payload, encoding: .utf8), !text.isEmpty {
                shellHandlers[localId]?(.success(text))
            }
            send(ADBPacket(command: ADBPacket.OKAY, arg0: packet.arg1, arg1: packet.arg0))

        case ADBPacket.CLSE:
            if packet.arg1 != 0 {
                send(ADBPacket(command: ADBPacket.CLSE, arg0: packet.arg1, arg1: packet.arg0))
                shellHandlers.removeValue(forKey: packet.arg1)?(.success(""))
            }

        default:
            break
        }
    }

    private func handleAuthToken(_ token: Data) {
        // TODO(v0.2)：用 ensureKeyPair() 的私钥签名 token 后回 AUTH(authSignature)，
        // 或首次连接发 AUTH(authPublicKey) 让设备弹授权框。这里先只记录，
        // 不发无效帧，避免握手被毒化；真机联调时按 ROM 行为补齐。
        log?("收到 AUTH TOKEN（\(token.count) 字节），RSA 认证待接入")
        _ = ensureKeyPair()
    }

    private func resolveConnect(_ result: Result<Void, Error>) {
        let handlers = connectHandlers
        connectHandlers.removeAll()
        DispatchQueue.main.async {
            handlers.forEach { $0(result) }
        }
    }

    private func failAll(_ error: Error) {
        resolveConnect(.failure(error))
    }
}
