//
//  ADBClient.swift
//  FusionRecorder
//
//  轻量 ADB client：无线 ADB 只用来启动采集 / push jar / 保活，视频流不挤进 adb。
//
//  协议帧：CNXN / AUTH / OPEN / WRTE / OKAY / CLSE（见 ADBPacket.swift）。
//  v0.3 骨架把能离线写完的部分全部写实：
//   · AUTH 状态机：第 1 轮回 SIGNATURE（已授权过直接放行），第 2 轮起回 PUBLICKEY（弹授权框）
//   · 通用 stream：shell: 与 sync: 共用一套 OPEN/WRTE/CLSE 多路复用
//   · sync push：按 AOSP SYNC.TXT 构造 SEND/DATA/DONE，把 APK/JAR 推到眼镜
//  真机唯一待联调：该 ROM 的授权框在收到 PUBLICKEY 后是否如标准 ADB 弹出。
//

import Foundation
import Network

enum ADBError: Error, LocalizedError {
    case connectionFailed(String)
    case notConnected
    case timeout

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message): return message
        case .notConnected: return "ADB 连接尚未就绪"
        case .timeout: return "ADB 操作超时"
        }
    }
}

final class ADBClient {
    /// 日志回传（UI 侧负责切主线程）
    var log: ((String) -> Void)?

    private final class Stream {
        let service: String
        var remoteId: UInt32?
        var received = Data()
        var onOpened: ((UInt32) -> Void)?
        var onData: ((UInt32, Data) -> Void)?
        var onClose: ((UInt32, Data) -> Void)?
        var timer: DispatchSourceTimer?
        init(_ service: String) { self.service = service }
    }

    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.lath.fusionrecorder.adb")
    private var buffer = Data()
    private var isReady = false
    private var connectHandlers: [(Result<Void, Error>) -> Void] = []
    private var streams: [UInt32: Stream] = [:]
    private var nextLocalId: UInt32 = 0x10000001
    private var authRound = 0
    private let finishLock = NSLock()

    init(host: String, port: UInt16 = 5555) {
        let nwPort = NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: 5555)!
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
        connection = NWConnection(to: endpoint, using: .tcp)
    }

    // MARK: - 连接

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

    /// 预先准备密钥（UI 显示指纹用；认证真正用起来在 handleAuthToken）
    @discardableResult
    func ensureKeyPair() -> Bool { ADBAuth.shared.hasKey }

    // MARK: - shell

    /// 执行一条 shell 命令，收集所有 WRTE 输出，CLSE 时回调一次完整字符串。
    func shell(_ command: String, timeout: TimeInterval = 15,
               completion: @escaping (Result<String, Error>) -> Void) {
        open(service: "shell:\(command)", timeout: timeout,
             onOpened: nil,
             onData: nil,
             onClose: { _, output in
                 completion(.success(String(decoding: output, as: UTF8.self)))
             },
             onTimeout: { completion(.failure(ADBError.timeout)) })
    }

    /// 启动一个长期运行的命令（屏幕流 sec=0 永不返回）。
    /// OPEN 成功即回调，之后收到的数据只记日志；直到 disconnect 才结束。
    func shellDetached(_ command: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard isReady else { completion(.failure(ADBError.notConnected)); return }
        open(service: "shell:\(command)", timeout: 0,
             onOpened: { _ in completion(.success(())) },
             onData: { [weak self] _, chunk in
                 let text = String(decoding: chunk, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                 if !text.isEmpty { self?.log?("[detached] \(text)") }
             },
             onClose: { [weak self] _, _ in
                 self?.log?("[detached] 通道已关闭")
             },
             onTimeout: nil)
    }

    // MARK: - sync push

    /// 把本地文件字节推到设备。path 用绝对路径，mode 如 0644。
    func push(path: String, data: Data, mode: UInt32 = 0o644,
              timeout: TimeInterval = 30,
              completion: @escaping (Result<Void, Error>) -> Void) {
        let frames = ADBSyncPusher.sendFrames(
            path: path, mode: mode, data: data,
            mtime: UInt32(Date().timeIntervalSince1970))
        var finished = false
        // 上一轮 push 可能留下半截响应帧，必须先清掉，否则会把旧字节当成这次的应答
        syncBuffer.removeAll(keepingCapacity: false)
        let finish: (Result<Void, Error>) -> Void = { [weak self] result in
            guard let self = self else { return }
            self.finishLock.lock()
            if finished { self.finishLock.unlock(); return }
            finished = true
            self.finishLock.unlock()
            DispatchQueue.main.async { completion(result) }
        }

        open(service: "sync:", timeout: timeout,
             onOpened: { [weak self] localId in
                 guard let self = self else { return }
                 for frame in frames { self.write(localId, frame) }
             },
             onData: { [weak self] localId, chunk in
                 guard let self = self else { return }
                 self.syncBuffer.append(chunk)
                 while let parsed = ADBSyncPusher.parseResponse(self.syncBuffer) {
                     self.syncBuffer.removeSubrange(0..<parsed.consumed)
                     switch parsed.outcome {
                     case .ok:
                         finish(.success(()))
                         self.closeStream(localId)
                     case .failed(let message):
                         finish(.failure(ADBSyncError.rejected(message)))
                         self.closeStream(localId)
                     case .ignored:
                         continue
                     }
                 }
             },
             onClose: { _, _ in
                 finish(.failure(ADBError.connectionFailed("sync 通道提前关闭")))
             },
             onTimeout: { finish(.failure(ADBError.timeout)) })
    }

    private var syncBuffer = Data()
    private var pullBuffer = Data()

    // MARK: - sync pull（0.4.0 离线录制：拉回眼镜本地的两个 mp4）

    /// 从设备拉取一个文件的完整字节。progress 回调已切到主线程，0...1。
    /// 拉取远端文件。timeout 是「空闲超时」：每收到一块数据就重新计时，
    /// 所以真正限制的是「链路卡死多久算失败」，而不是总时长。
    /// 眼镜实测无线 ADB 只有 0.2~0.5MB/s，1 分钟录制约 12MB，硬性总超时会误杀。
    func pull(path: String, timeout: TimeInterval = 45,
              progress: ((Double) -> Void)? = nil,
              completion: @escaping (Result<Data, Error>) -> Void) {
        let request = ADBSyncPuller.recvFrame(path: path)
        var finished = false
        let finish: (Result<Data, Error>) -> Void = { [weak self] result in
            guard let self = self else { return }
            self.finishLock.lock()
            if finished { self.finishLock.unlock(); return }
            finished = true
            self.finishLock.unlock()
            DispatchQueue.main.async { completion(result) }
        }

        var fileData = Data()
        var expectedSize: Int?
        pullBuffer.removeAll(keepingCapacity: false)

        open(service: "sync:", timeout: timeout,
             onOpened: { [weak self] localId in
                 guard let self = self else { return }
                 self.write(localId, request)
             },
             onData: { [weak self] localId, chunk in
                 guard let self = self else { return }
                 self.bumpTimeout(localId, timeout: timeout)
                 self.pullBuffer.append(chunk)
                 let parsed = ADBSyncPuller.parseResponses(self.pullBuffer)
                 if parsed.consumed > 0 {
                     self.pullBuffer.removeSubrange(0..<parsed.consumed)
                 }
                 for event in parsed.events {
                     switch event {
                     case .dent(let size):
                         expectedSize = size > 0 ? size : nil
                     case .data(let block):
                         fileData.append(block)
                     case .done:
                         if fileData.isEmpty {
                             finish(.failure(ADBSyncPullError.emptyFile(path)))
                         } else {
                             finish(.success(fileData))
                             log?("pull 完成：\(path) \(fileData.count) 字节")
                         }
                         self.closeStream(localId)
                     case .failed(let message):
                         finish(.failure(ADBSyncPullError.rejected(message)))
                         self.closeStream(localId)
                     }
                 }
                 if let total = expectedSize, total > 0 {
                     let ratio = min(1.0, Double(fileData.count) / Double(total))
                     DispatchQueue.main.async { progress?(ratio) }
                 }
             },
             onClose: { _, _ in
                 finish(.failure(ADBError.connectionFailed("sync 通道提前关闭")))
             },
             onTimeout: {
                 finish(.failure(ADBSyncPullError.timeout))
             })
    }

    // MARK: - 通用 stream

    @discardableResult
    private func open(service: String, timeout: TimeInterval,
                      onOpened: ((UInt32) -> Void)?,
                      onData: ((UInt32, Data) -> Void)?,
                      onClose: ((UInt32, Data) -> Void)?,
                      onTimeout: (() -> Void)?) -> UInt32? {
        guard isReady else { return nil }
        let localId = nextLocalId
        nextLocalId &+= 1
        let stream = Stream(service)
        stream.onOpened = onOpened
        stream.onData = onData
        stream.onClose = onClose
        streams[localId] = stream

        if timeout > 0 {
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + timeout)
            timer.setEventHandler { [weak self] in
                guard let self = self, let stream = self.streams[localId] else { return }
                self.streams.removeValue(forKey: localId)
                stream.timer?.cancel()
                onTimeout?()
            }
            timer.resume()
            stream.timer = timer
        }

        var payload = Data(service.utf8)
        payload.append(0)
        send(ADBPacket(command: ADBPacket.OPEN, arg0: localId, arg1: 0, payload: payload))
        return localId
    }

    /// 把流的超时往后推（幂等）：有大块数据在流动就说明链路还活着。
    private func bumpTimeout(_ localId: UInt32, timeout: TimeInterval) {
        guard timeout > 0, let stream = streams[localId], let timer = stream.timer else { return }
        timer.schedule(deadline: .now() + timeout)
    }

    private func write(_ localId: UInt32, _ payload: Data) {
        guard let stream = streams[localId], let remoteId = stream.remoteId else { return }
        send(ADBPacket(command: ADBPacket.WRTE, arg0: localId, arg1: remoteId, payload: payload))
    }

    private func closeStream(_ localId: UInt32) {
        guard let stream = streams.removeValue(forKey: localId) else { return }
        stream.timer?.cancel()
        let remoteId = stream.remoteId ?? 0
        send(ADBPacket(command: ADBPacket.CLSE, arg0: localId, arg1: remoteId))
    }

    // MARK: - 底层收发

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
            // OPEN 的确认（真机 adbd 语义，2026-11-20 实测确认）：
            //   arg0 = 设备分配的 remoteId（后续 WRTE/CLSE 的 arg1 要用它）
            //   arg1 = 客户端 localId 的 echo（用它找 stream）
            // 之前写反成 arg0=localId/arg1=remoteId，导致 sync push 时
            // WRTE 的 arg1 填成自己的 localId，真 adbd 直接断开连接 →
            // "push 屏幕流 dex 失败: ADB 操作超时"。shell 只被动收 WRTE 不受影响，
            // 所以之前没暴露。mock adbd 也写反了，离线自测 3/3 也没抓到。
            let localId = packet.arg1
            if let stream = streams[localId], stream.remoteId == nil {
                stream.remoteId = packet.arg0
                log?("stream \(packet.arg0) 已就绪 (\(stream.service))")
                stream.onOpened?(localId)
            }

        case ADBPacket.WRTE:
            let localId = packet.arg1
            if let stream = streams[localId] {
                stream.received.append(packet.payload)
                stream.onData?(localId, packet.payload)
            }
            send(ADBPacket(command: ADBPacket.OKAY, arg0: packet.arg1, arg1: packet.arg0))

        case ADBPacket.CLSE:
            let localId = packet.arg1
            if let stream = streams.removeValue(forKey: localId) {
                stream.timer?.cancel()
                send(ADBPacket(command: ADBPacket.CLSE, arg0: localId, arg1: stream.remoteId ?? 0))
                stream.onClose?(localId, stream.received)
            }

        default:
            break
        }
    }

    private func handleAuthToken(_ token: Data) {
        authRound += 1
        if authRound == 1, let signature = ADBAuth.shared.signature(for: token) {
            // 已授权过：设备认这个签名就直接回 CNXN
            log?("AUTH 第 1 轮：回 SIGNATURE（\(signature.count) 字节）")
            send(ADBPacket(command: ADBPacket.AUTH, arg0: ADBPacket.authSignature, payload: signature))
        } else if let publicKey = ADBAuth.shared.publicKeyPayload() {
            // 首次连接 / 签名未被接受：回公钥，让设备弹「允许 USB/Wi-Fi 调试」
            log?("AUTH 第 \(authRound) 轮：回 PUBLICKEY（等待设备授权框）")
            send(ADBPacket(command: ADBPacket.AUTH, arg0: ADBPacket.authPublicKey, payload: publicKey))
        } else {
            log?("AUTH：密钥未就绪，等待真机联调")
        }
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
