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

    /// 选出「下发采集端启动命令时该填的 iPhone IP」——眼镜要主动连这个地址。
    ///
    /// 不能盲目取 localIPv4().first：iPhone 上接口顺序不定，首个可能是
    /// 16.x 的虚拟/VPN 接口（2026-11-20 真机实测取到 16.2.0.0，眼镜连不上）。
    /// 策略：① 与眼镜同 /24 网段的本机 IP 最优（采集端和它必然可达）；
    ///       ② 否则取 RFC1918 私有地址（192.168/10/172.16-31）；
    ///       ③ 再不行退回第一个非 loopback。
    func bestLocalIP(for glassesIP: String?) -> String? {
        Self.pickLocalIP(from: localIPv4(), glassesIP: glassesIP)
    }

    /// 纯函数版（便于离线单测）：从候选 IP 列表里挑出该下发给眼镜的 host。
    static func pickLocalIP(from all: [String], glassesIP: String?) -> String? {
        guard !all.isEmpty else { return nil }

        func octets(_ s: String) -> [Int]? {
            let p = s.split(separator: ".").compactMap { Int($0) }
            return p.count == 4 ? p : nil
        }
        func isPrivate(_ s: String) -> Bool {
            guard let p = octets(s) else { return false }
            if p[0] == 10 { return true }
            if p[0] == 192 && p[1] == 168 { return true }
            if p[0] == 172 && (16...31).contains(p[1]) { return true }
            return false
        }

        // ① 同网段优先
        if let g = glassesIP, let gp = octets(g) {
            if let sameSubnet = all.first(where: {
                guard let p = octets($0) else { return false }
                return p[0] == gp[0] && p[1] == gp[1] && p[2] == gp[2]
            }) {
                return sameSubnet
            }
        }
        // ② 私有地址
        if let privateIP = all.first(where: { isPrivate($0) }) {
            return privateIP
        }
        // ③ 兜底
        return all.first
    }

    /// 界面上「本机 IP」该显示哪个：只认局域网私有地址。
    ///
    /// 真机踩过：iPhone 开着 VPN 时 `localIPv4()` 里会先冒出 16.2.0.0 这类
    /// 虚拟接口地址，直接显示出来会让人以为是「IP 不对」。
    /// 这里只在 RFC1918 里挑，挑不到就返回 nil，由界面显示「未获取」并给建议。
    func lanIP(for glassesIP: String?) -> String? {
        let all = localIPv4()
        if let same = Self.pickLocalIP(from: all.filter(Self.isPrivateIPv4), glassesIP: glassesIP) {
            return same
        }
        return nil
    }

    static func isPrivateIPv4(_ s: String) -> Bool {
        let p = s.split(separator: ".").compactMap { Int($0) }
        guard p.count == 4 else { return false }
        if p[0] == 10 { return true }
        if p[0] == 192 && p[1] == 168 { return true }
        if p[0] == 172 && (16...31).contains(p[1]) { return true }
        return false
    }

    /// 两个地址是否在同一 /24（眼镜和 iPhone 必须同网段才能互连）。
    static func sameSubnet(_ a: String, _ b: String) -> Bool {
        let pa = a.split(separator: ".").compactMap { Int($0) }
        let pb = b.split(separator: ".").compactMap { Int($0) }
        guard pa.count == 4, pb.count == 4 else { return false }
        return pa[0] == pb[0] && pa[1] == pb[1] && pa[2] == pb[2]
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
