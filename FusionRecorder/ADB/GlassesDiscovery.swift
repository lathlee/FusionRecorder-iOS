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

    /// iPhone 开热点时，第一个连上来的设备通常是 172.20.10.2。
    /// 换网络后（WiFi → 热点）眼镜地址会整个变掉，扫描时把这个地址一起探一下，
    /// 能在 /24 全扫之前就命中。
    static let hotspotGlassesIP = "172.20.10.2"

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

    /// 接口名 + IPv4（诊断用）。能看到是 `en0`（WiFi）还是 `utun3`（VPN）：
    /// 界面显示「未获取到局域网 IP」时，这一行就能定性。
    func localIPv4Named() -> [(name: String, ip: String)] {
        var result: [(name: String, ip: String)] = []
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
                    var name = "?"
                    if let namePtr = ifa.ifa_name { name = String(cString: namePtr) }
                    if ip != "127.0.0.1" { result.append((name: name, ip: ip)) }
                }
            }
            cursor = ifa.ifa_next
        }
        return result
    }

    /// 所有接口的 IPv4 清单，纯粹给部署日志看（诊断用）。
    /// 真机踩过：界面上「本机 IP 未获取到」，但日志里能看到到底有哪些接口、
    /// 是不是只有 VPN 的 16.x，一眼就能判断问题在哪。
    func interfaceDump() -> String {
        let all = localIPv4Named()
        if all.isEmpty { return "无 IPv4 接口（连 127.0.0.1 都没有，异常）" }
        return all.map { item -> String in
            // 别在插值里嵌三元字符串：`"\(a ? "" : "x")"` 这种写法会把字面量提前截断，
            // 编译期报「consecutive statements on a line must be separated by ';'」。
            let tag = Self.isPrivateIPv4(item.ip) ? "" : "(非局域网)"
            return item.name + "=" + item.ip + tag
        }.joined(separator: " · ")
    }

    /// 界面显示用：**只认局域网私有地址**。
    /// 0.5.6 会退到「第一个非 loopback」，结果真机上把 VPN 的 16.2.0.0 显示成
    /// 「本机 16.2.0.0」，用户直接判定「识别的 IP 不对」。那个地址对离线录制没用，
    /// 宁可不显示。
    func displayLocalIP(for glassesIP: String?) -> String? {
        let all = localIPv4()
        return Self.pickLocalIP(from: all.filter(Self.isPrivateIPv4), glassesIP: glassesIP)
    }

    // MARK: - 主动申请「本地网络」权限

    private var permissionBrowser: NWBrowser?
    private var broadcastProbe: NWConnection?

    /// 主动触发 iOS 的「本地网络」权限框（0.5.6 新增）。
    ///
    /// 为什么必须要它：iOS 14+ 只有在 App **真的去访问局域网**时才弹框。
    /// 之前所有版本都没主动访问过 —— 本机地址读不到 → 拼不出 /24 候选 →
    /// 从不去连局域网 IP → 系统永不弹框 → 【设置 → 隐私与安全性 → 本地网络】里
    /// 永远没有本 App 这一项。用户反馈「找不到这个开关」正是这个死循环。
    /// 开一个 Bonjour 浏览器 + 发一个 UDP 广播，系统就会判定要访问局域网并弹框。
    func requestLocalNetworkPermission() {
        triggerBroadcastProbe()
        guard permissionBrowser == nil else { return }
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_adb-tls-connect._tcp", domain: nil),
                                using: params)
        permissionBrowser = browser
        browser.stateUpdateHandler = { [weak self] (state: NWBrowser.State) in
            switch state {
            case .ready:
                NSLog("[Discovery] Bonjour 就绪：本地网络权限已放行")
            case .failed(let error):
                NSLog("[Discovery] Bonjour 失败：\(error.localizedDescription)")
                self?.permissionBrowser?.cancel()
                self?.permissionBrowser = nil
            default:
                break
            }
        }
        browser.browseResultsChangedHandler = {
            (results: Set<NWBrowser.Result>, _: Set<NWBrowser.Result.Change>) in
            for result in results {
                NSLog("[Discovery] Bonjour 服务：\(result.endpoint)")
            }
        }
        browser.start(queue: DispatchQueue.global(qos: .utility))
    }

    /// UDP 广播探测：不依赖 Info.plist 的 Bonjour 声明也能触发权限框。
    private func triggerBroadcastProbe() {
        if broadcastProbe != nil { return }
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        let conn = NWConnection(host: "255.255.255.255", port: 9, using: params)
        broadcastProbe = conn
        conn.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                NSLog("[Discovery] 广播探测结束：\(error.localizedDescription)")
                self?.broadcastProbe?.cancel()
                self?.broadcastProbe = nil
            }
        }
        conn.start(queue: DispatchQueue.global(qos: .utility))
        conn.send(content: Data([0x00]), completion: .contentProcessed { _ in })
    }

    /// 扫描候选地址：上次成功的 IP 优先，然后本机各网段的 /24。
    ///
    /// ★ 0.5.5：可以额外塞入「已知的眼镜 IP」（手动填的那个）。
    /// 这一步不只是为了快点找到 —— 它同时**触发 iOS 的「本地网络」权限框**：
    /// 如果本机一个局域网地址都读不到，就永远拼不出 /24 候选，
    /// 也就永远不去连局域网 IP，系统于是永远不弹权限框 —— 死循环。
    /// 用已知 IP 硬探一次，把这个环打断。
    func candidateIPs(extra: [String] = []) -> [String] {
        var ordered: [String] = []
        for ip in extra where !ip.isEmpty {
            if !ordered.contains(ip) { ordered.append(ip) }
        }
        if let last = lastIP, !ordered.contains(last) { ordered.append(last) }
        // iOS 热点的网段固定是 172.20.10.0/28（可用 .1~.14），一共就 13 个地址。
        // 0.5.7：整段都探一遍 —— 真机上「本机 IP」经常读不到本机局域网接口
        // （只剩 VPN 的 utun），那样就拼不出 /24，切到热点后永远找不到眼镜。
        // 这一段不依赖本机地址，14 次探测摊到并发池里几乎不花钱。
        for host in 2...14 {
            let ip = "172.20.10.\(host)"
            if !ordered.contains(ip) { ordered.append(ip) }
        }
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
    func scan(extra: [String] = [],
              progress: ((Int, Int) -> Void)? = nil,
              completion: @escaping (DiscoveryResult?) -> Void) {
        let candidates = candidateIPs(extra: extra)
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
                // ★ 0.5.8：已知地址给更长的超时。
                // 真机上出现过「预览能连上这个 IP，扫描却一个都没命中」——
                // 0.45 秒对一次要走 VPN/隧道的 TCP 握手指令来说太紧了。
                let known = (ip == self.lastIP) || extra.contains(ip)
                let reachable = self.probe(ip: ip, port: self.adbPort,
                                           timeout: known ? 1.5 : 0.6)
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
