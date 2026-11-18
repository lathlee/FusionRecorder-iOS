//
//  GlassesDiscovery.swift
//  FusionRecorder
//
//  自动发现眼镜：
//   1) 用上次成功的 IP 先试（UserDefaults，冷启动秒连）
//   2) 扫本机所在的 /24 网段 5555 端口（热点模式通常是 172.20.10.x）
//   3) 连上之后再交给 ADBClient 做真正的 CNXN/AUTH 握手——这里只判断端口可达
//
//  iOS 14+ 首次扫局域网会弹「本地网络」权限框（Info.plist 已声明用途）。
//  骨架阶段扫描结果只做候选，真正的身份确认靠 ADB `id` 命令（须 uid=2000 shell）。
//

import Foundation
import Network
#if canImport(Darwin)
import Darwin
#endif

struct DiscoveryResult {
    let ip: String
    let source: String          // "上次连接" / "网段扫描"
}

final class GlassesDiscovery {

    static let shared = GlassesDiscovery()
    private let defaults = UserDefaults.standard
    private let lastIPKey = "fusion.lastGlassesIP"
    private let adbPort: UInt16 = 5555

    private init() {}

    var lastIP: String? {
        let value = defaults.string(forKey: lastIPKey) ?? ""
        return value.isEmpty ? nil : value
    }

    func remember(_ ip: String) {
        defaults.set(ip, forKey: lastIPKey)
    }

    func forget() {
        defaults.removeObject(forKey: lastIPKey)
    }

    /// 本机 IPv4（去掉 loopback）。iPhone 开热点时通常是 172.20.10.1。
    func localIPv4() -> [String] {
        var result: [String] = []
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return result }
        defer { freeifaddrs(addresses) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            let ifa = current.pointee
            if let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                if inet_ntop(AF_INET, addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil {
                    let ip = String(cString: buffer)
                    if ip != "127.0.0.1" { result.append(ip) }
                }
            }
            cursor = ifa.ifa_next
        }
        return result
    }

    /// 扫描候选地址：上次成功的 IP 优先，然后本机各网段的 /24。
    func candidateIPs() -> [String] {
        var ordered: [String] = []
        if let last = lastIP { ordered.append(last) }
        for local in localIPv4() {
            let parts = local.split(separator: ".").compactMap { Int($0) }
            guard parts.count == 4 else { continue }
            for host in 1...254 where host != parts[3] {
                let ip = "\(parts[0]).\(parts[1]).\(parts[2]).\(host)"
                if !ordered.contains(ip) { ordered.append(ip) }
            }
        }
        return ordered
    }

    /// 并发探测 5555 是否可达；命中第一个即回调（不等待全表扫完）。
    /// - parameters:
    ///   - progress: 已探测数 / 总数，用于 UI 显示进度
    ///   - completion: 命中的候选；nil 表示整表扫完没有可达设备
    func scan(progress: ((Int, Int) -> Void)? = nil,
              completion: @escaping (DiscoveryResult?) -> Void) {
        let candidates = candidateIPs()
        guard !candidates.isEmpty else {
            completion(nil)
            return
        }

        let lock = NSLock()
        var finished = false
        var probed = 0
        let total = candidates.count
        let pool = DispatchQueue(label: "com.lath.fusionrecorder.discovery", attributes: .concurrent)
        let group = DispatchGroup()

        for ip in candidates {
            group.enter()
            pool.async {
                defer { group.leave() }
                let reachable = self.probe(ip: ip, port: self.adbPort, timeout: 0.45)
                lock.lock()
                probed += 1
                let done = finished
                if reachable && !finished { finished = true }
                let current = probed
                lock.unlock()
                progress?(current, total)
                if reachable && !done {
                    let source = (ip == self.lastIP) ? "上次连接" : "网段扫描"
                    DispatchQueue.main.async { completion(DiscoveryResult(ip: ip, source: source)) }
                }
            }
        }
        group.notify(queue: .main) {
            lock.lock()
            let found = finished
            lock.unlock()
            if !found { completion(nil) }
        }
    }

    private func probe(ip: String, port: UInt16, timeout: TimeInterval) -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return false }
        let connection = NWConnection(host: NWEndpoint.Host(ip), port: nwPort, using: .tcp)
        let semaphore = DispatchSemaphore(value: 0)
        var reached = false
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                reached = true
                semaphore.signal()
            case .failed, .cancelled:
                semaphore.signal()
            default:
                break
            }
        }
        connection.start(queue: DispatchQueue.global())
        let result = semaphore.wait(timeout: .now() + timeout)
        connection.cancel()
        return result == .success && reached
    }
}
