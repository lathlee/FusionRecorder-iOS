//
//  CaptureOrchestrator.swift
//  FusionRecorder
//
//  眼镜采集端「全自动部署」编排器（v0.3 骨架）。
//  把交接包 DEPLOY.md 里人手敲的命令串成一条状态机：
//    发现 → 连接/AUTH → 校验 shell 身份 → push jar+apk → 安装 → 授相机权限
//         → 启动屏幕流(9114) → 启动相机流(9115) → 保活(可选)
//
//  ★ 关键方向（容易搞反）：启动命令里的 host 是【iPhone 的 IP】，
//    因为采集端主动连 iPhone 的监听端口；不是眼镜自己的 IP。
//  ★ 接收端必须处于监听姿态才能对上这个方向。v0.3 已提供 H264StreamListener
//    （NWListener 服务端）；RecorderSession.startAuto 走监听，手动抓帧仍走
//    H264StreamReceiver（客户端），两者并存、共用 H264NALSplitter。
//
//  真机待联调的唯一项：ROM 在收到 AUTH_PUBLICKEY 后是否弹授权框（ADBAuth 已按标准实现）。
//

import Foundation
import Combine

enum CaptureStage: String {
    case idle = "待机"
    case discovering = "发现眼镜"
    case connecting = "连接 / 授权"
    case verifying = "校验身份"
    case deploying = "部署采集端"
    case starting = "启动两路流"
    case ready = "就绪"
    case failed = "失败"
}

final class CaptureOrchestrator: ObservableObject {

    @Published private(set) var stage: CaptureStage = .idle
    @Published private(set) var stageDetail = ""
    @Published private(set) var log: [String] = []
    @Published private(set) var isBusy = false
    @Published private(set) var glassesIP: String?
    @Published private(set) var iphoneIP: String?

    private var adb: ADBClient?
    private var deploymentOnly = false

    // MARK: - 命令构造（静态，便于离线对拍）

    static func idCommand() -> String { "id" }

    static func screenPushPath() -> String { "/data/local/tmp/screen-push.jar" }
    static func apkPushPath() -> String { "/data/local/tmp/fusion-capture.apk" }

    static func installCommand() -> String {
        "pm install -r \(apkPushPath())"
    }

    static func grantCameraCommand() -> String {
        "pm grant com.fusion.capture android.permission.CAMERA"
    }

    /// 屏幕流用 shellDetached：sec=0 永不返回，通道保持打开。
    static func screenStartCommand(iphoneIP: String, port: UInt16 = 9114,
                                   width: Int = 640, height: Int = 400,
                                   fps: Int = 20, pts: Bool = true) -> String {
        "CLASSPATH=\(screenPushPath()) app_process / poc.ScreenPush \(iphoneIP) \(port) 0 \(width) \(height) \(fps) 2000000 2 \(pts ? 1 : 0)"
    }

    static func cameraStartCommand(iphoneIP: String, port: UInt16 = 9115,
                                   fps: Int = 30, pts: Bool = true) -> String {
        "am start-foreground-service -n com.fusion.capture/.CameraStreamService --es host \(iphoneIP) --ei port \(port) --ei sec 0 --ei width 640 --ei height 480 --ei fps \(fps) --ei bitrate 2000000 --ei iframe 2 --ei pts \(pts ? 1 : 0)"
    }

    static func keepAliveCommand() -> String {
        "am start -n com.fusion.capture/.KeepAliveActivity"
    }

    // MARK: - 0.4.0 离线录制命令（替代原来的实时推流启动）

    static let screenMP4Path = "/data/local/tmp/fusion_screen.mp4"
    /// 相机 mp4 必须落在 App 自己能写的地方。/data/local/tmp 对 untrusted_app
    /// 是 SELinux 硬限制（改 chmod 也 EACCES），所以用 App 的外部私有目录：
    /// App 可写，shell(ADB pull) 也能读（sdcardfs 按目录归属映射）。
    static let cameraMP4Dir = "/sdcard/Android/data/com.fusion.capture/files"
    static let cameraMP4Path = cameraMP4Dir + "/fusion_camera.mp4"
    static let screenStopFlag = "/data/local/tmp/fusion_stop_screen"

    /// 录制前的准备：确保相机目录存在、清掉上次的停止标记。
    static func prepareRecordCommand() -> String {
        "mkdir -p \(cameraMP4Dir); rm -f \(screenStopFlag)"
    }

    /// 屏幕流：shell uid 的 app_process 本地录 mp4。参数槽位：
    /// ScreenPush <outPath> <sec> <w> <h> <fps> <bitrate> <iframe> <pts占位> <repeatUs>
    static func screenRecordStartCommand(path: String = screenMP4Path,
                                         width: Int = 640, height: Int = 400,
                                         fps: Int = 20, bitrate: Int = 2_000_000,
                                         iframe: Int = 2,
                                         repeatUs: Int = 50_000) -> String {
        "CLASSPATH=\(screenPushPath()) app_process / poc.ScreenPush \(path) 0 \(width) \(height) \(fps) \(bitrate) \(iframe) 0 \(repeatUs)"
    }

    /// 相机流：App uid 的前台服务本地录 mp4。
    static func cameraRecordStartCommand(path: String = cameraMP4Path,
                                         width: Int = 640, height: Int = 480,
                                         fps: Int = 30, bitrate: Int = 2_000_000,
                                         iframe: Int = 2,
                                         repeatUs: Int = 33_333) -> String {
        "am start-foreground-service -n com.fusion.capture/.CameraStreamService --es path \(path) --ei sec 0 --ei width \(width) --ei height \(height) --ei fps \(fps) --ei bitrate \(bitrate) --ei iframe \(iframe) --ei repeat_us \(repeatUs)"
    }

    /// 清掉上一次残留的停止标记（新录制启动时 ScreenPush 自己也会删一次）
    static func cleanStopFlagCommand() -> String { "rm -f \(screenStopFlag)" }

    /// 屏幕录制停止：touch 标记文件，主循环下一轮检测到就优雅收尾
    static func stopScreenRecordCommand() -> String { "touch \(screenStopFlag)" }

    /// 相机录制停止：带 STOP action 再 start 一次服务，
    /// 不能 stopService —— 那会让 muxer 来不及写 moov。
    static func stopCameraRecordCommand() -> String {
        "am startservice -n com.fusion.capture/.CameraStreamService -a com.fusion.capture.STOP_CAMERA"
    }

    /// 等两个 mp4 写完：连续两次采样大小一致且非零。
    static func waitFilesCommand() -> String {
        let s = screenMP4Path
        let c = cameraMP4Path
        return "s1=$(stat -c %s \(s) 2>/dev/null || echo 0); c1=$(stat -c %s \(c) 2>/dev/null || echo 0); sleep 0.5; s2=$(stat -c %s \(s) 2>/dev/null || echo 0); c2=$(stat -c %s \(c) 2>/dev/null || echo 0); if [ \"$s1\" = \"$s2\" ] && [ \"$c1\" = \"$c2\" ] && [ \"$s1\" != \"0\" ] && [ \"$c1\" != \"0\" ]; then echo READY screen=$s2 camera=$c2; else echo WAITING screen=$s2/$s1 camera=$c2/$c1; fi"
    }

    static func stopCameraCommand() -> String {
        "am broadcast -a com.fusion.capture.STOP_CAMERA -n com.fusion.capture/.CaptureReceiver"
    }

    static func forceStopCommand() -> String {
        "am force-stop com.fusion.capture"
    }

    /// 校验命令串里绝不出现换行/控制字符（ADB OPEN payload 以 NUL 结尾，换行会破坏 shell 语义）。
    static func isSafeCommand(_ command: String) -> Bool {
        !command.contains { $0 == "\n" || $0 == "\r" || $0 == "\0" }
    }

    // MARK: - 编排

    /// 全自动入口。host 传入则跳过扫描（手动指定眼镜 IP）。
    func run(host: String? = nil, iphoneHostIP: String? = nil,
             completion: @escaping (Result<String, Error>) -> Void) {
        guard !isBusy else {
            completion(.failure(ADBError.connectionFailed("已有部署流程在执行")))
            return
        }
        isBusy = true
        resetLog()

        // phoneIP 必须在眼镜 IP 确定之后再算：用它选「与眼镜同网段」的本机地址。
        // 之前在函数开头就 localIPv4().first，取到过 16.2.0.0 虚拟接口 → 眼镜连不上。
        func deploy(to glassesAddress: String) {
            let phone = iphoneHostIP ?? GlassesDiscovery.shared.bestLocalIP(for: glassesAddress)
            guard let phoneIP = phone else {
                self.finishFailure("无法确定 iPhone 局域网 IP：确认已连上 WiFi/热点", completion: completion)
                return
            }
            self.iphoneIP = phoneIP
            self.append("本机 IP：\(phoneIP)（下发采集端的 host，眼镜会连它）")
            self.connectAndDeploy(glassesIP: glassesAddress, iphoneIP: phoneIP, completion: completion)
        }

        if let given = host, !given.isEmpty {
            glassesIP = given
            append("使用指定眼镜 IP：\(given)")
            deploy(to: given)
        } else {
            setStage(.discovering, "扫描 5555 端口（上次 IP 优先）…")
            GlassesDiscovery.shared.scan { [weak self] result in
                guard let self = self else { return }
                guard let found = result else {
                    self.finishFailure("未发现眼镜：确认眼镜连上 iPhone 热点、无线 ADB 已开（5555）", completion: completion)
                    return
                }
                self.glassesIP = found.ip
                self.append("发现眼镜 \(found.ip)（\(found.source)）")
                deploy(to: found.ip)
            }
        }
    }

    /// 只重新部署采集端（不启动流），用于更新 APK/JAR 后。
    func redeploy(host: String, iphoneHostIP: String? = nil,
                  completion: @escaping (Result<String, Error>) -> Void) {
        deploymentOnly = true
        run(host: host, iphoneHostIP: iphoneHostIP, completion: completion)
    }

    private func connectAndDeploy(glassesIP: String, iphoneIP: String?,
                                  completion: @escaping (Result<String, Error>) -> Void) {
        guard let phoneIP = iphoneIP else {
            finishFailure("拿不到 iPhone 的局域网 IP，无法告诉眼镜往哪推流；请手动指定", completion: completion)
            return
        }

        let client = ADBClient(host: glassesIP, port: 5555)
        client.log = { [weak self] message in self?.append("[ADB] \(message)") }
        adb = client
        setStage(.connecting, "CNXN / AUTH 握手（首次需在眼镜上点允许调试）")

        client.connect { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                self.finishFailure("ADB 连接失败：\(error.localizedDescription)（首次授权请在眼镜上确认弹框）", completion: completion)
                return
            case .success:
                self.append("ADB 已授权并握手完成，指纹 \(ADBAuth.shared.fingerprint)")
                self.verifyShell(client: client, phoneIP: phoneIP, completion: completion)
            }
        }
    }

    private func verifyShell(client: ADBClient, phoneIP: String,
                             completion: @escaping (Result<String, Error>) -> Void) {
        setStage(.verifying, "执行 id，确认是 shell(uid=2000)")
        client.shell(Self.idCommand()) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                self.finishFailure("id 命令失败：\(error.localizedDescription)", completion: completion)
            case .success(let output):
                self.append("身份：\(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                guard output.contains("uid=2000") else {
                    self.finishFailure("当前不是 shell 身份，屏幕流无法抓屏（抓屏只能靠 shell uid）", completion: completion)
                    return
                }
                self.deployAssets(client: client, phoneIP: phoneIP, completion: completion)
            }
        }
    }

    private func deployAssets(client: ADBClient, phoneIP: String,
                              completion: @escaping (Result<String, Error>) -> Void) {
        setStage(.deploying, "push screen-push.jar + fusion-capture.apk")
        guard let jar = Bundle.main.url(forResource: "screen-push", withExtension: "jar"),
              let apk = Bundle.main.url(forResource: "fusion-capture", withExtension: "apk"),
              let jarData = try? Data(contentsOf: jar),
              let apkData = try? Data(contentsOf: apk) else {
            finishFailure("App 内找不到采集端资源（screen-push.jar / fusion-capture.apk）", completion: completion)
            return
        }

        client.push(path: Self.screenPushPath(), data: jarData) { [weak self] jarResult in
            guard let self = self else { return }
            switch jarResult {
            case .failure(let error):
                self.finishFailure("push 屏幕流 dex 失败：\(error.localizedDescription)", completion: completion)
                return
            case .success:
                self.append("screen-push.jar 已推送（\(jarData.count) 字节）")
            }

            client.push(path: Self.apkPushPath(), data: apkData) { apkResult in
                switch apkResult {
                case .failure(let error):
                    self.finishFailure("push APK 失败：\(error.localizedDescription)", completion: completion)
                case .success:
                    self.append("fusion-capture.apk 已推送（\(apkData.count) 字节）")
                    self.installAndGrant(client: client, phoneIP: phoneIP, completion: completion)
                }
            }
        }
    }

    private func installAndGrant(client: ADBClient, phoneIP: String,
                                 completion: @escaping (Result<String, Error>) -> Void) {
        append("安装采集端 APK…")
        client.shell(Self.installCommand(), timeout: 60) { [weak self] installResult in
            guard let self = self else { return }
            switch installResult {
            case .failure(let error):
                self.finishFailure("安装失败：\(error.localizedDescription)", completion: completion)
                return
            case .success(let output):
                let text = output.trimmingCharacters(in: .whitespacesAndNewlines)
                self.append("安装输出：\(text)")
                if text.lowercased().contains("failure") {
                    self.finishFailure("安装失败：\(text)", completion: completion)
                    return
                }
            }

            self.append("授予 CAMERA 权限…")
            client.shell(Self.grantCameraCommand()) { grantResult in
                switch grantResult {
                case .failure(let error):
                    self.finishFailure("授权相机失败：\(error.localizedDescription)", completion: completion)
                case .success:
                    self.append("CAMERA 权限已授予")
                    // 0.4.0：部署阶段只负责把采集端装好。启动本地录制、停止、
                    // ADB pull 都由 RecorderSession 用自己那条连接完成，
                    // 不再按 0.3.x 的方式启动实时推流（9114/9115）。
                    self.finishSuccess("采集端已部署（离线录制模式）", completion: completion)
                }
            }
        }
    }

    private func startStreams(client: ADBClient, phoneIP: String,
                              completion: @escaping (Result<String, Error>) -> Void) {
        setStage(.starting, "启动两路采集（host = iPhone \(phoneIP)）")

        // 屏幕流：长期命令，OPEN 成功即返回，通道保持
        let screenCmd = Self.screenStartCommand(iphoneIP: phoneIP)
        guard Self.isSafeCommand(screenCmd) else {
            finishFailure("屏幕流命令含非法字符", completion: completion)
            return
        }
        client.shellDetached(screenCmd) { [weak self] screenResult in
            guard let self = self else { return }
            switch screenResult {
            case .failure(let error):
                self.finishFailure("启动屏幕流失败：\(error.localizedDescription)", completion: completion)
                return
            case .success:
                self.append("屏幕流 9114 已下发（shellDetached，host=\(phoneIP)）")
            }

            // 相机流：前台服务，命令很快返回
            let cameraCmd = Self.cameraStartCommand(iphoneIP: phoneIP)
            guard Self.isSafeCommand(cameraCmd) else {
                self.finishFailure("相机流命令含非法字符", completion: completion)
                return
            }
            client.shell(cameraCmd) { [weak self] cameraResult in
                guard let self = self else { return }
                switch cameraResult {
                case .failure(let error):
                    self.finishFailure("启动相机流失败：\(error.localizedDescription)", completion: completion)
                case .success(let output):
                    self.append("相机流 9115 已下发：\(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                    // 保活尽力而为，失败不影响就绪（多数 ROM 不需要）
                    client.shell(Self.keepAliveCommand()) { _ in
                        self.finishSuccess("两路采集已启动，屏幕 9114 / 相机 9115 → \(phoneIP)", completion: completion)
                    }
                }
            }
        }
    }

    /// 停止采集（ADB 侧；流接收侧由 RecorderSession 断开 TCP）。
    func stop(completion: @escaping () -> Void) {
        guard let client = adb else { completion(); return }
        client.shell(Self.stopCameraCommand()) { _ in
            client.shell(Self.forceStopCommand()) { _ in
                client.disconnect()
                self.adb = nil
                DispatchQueue.main.async {
                    self.setStage(.idle, "已停止采集端")
                    completion()
                }
            }
        }
    }

    // MARK: - 状态 / 日志

    private func setStage(_ stage: CaptureStage, _ detail: String) {
        DispatchQueue.main.async {
            self.stage = stage
            self.stageDetail = detail
            self.isBusy = (stage != .idle && stage != .ready && stage != .failed)
            self.append(detail)
        }
    }

    private func finishSuccess(_ message: String, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.main.async {
            self.stage = .ready
            self.stageDetail = message
            self.isBusy = false
            self.append("✓ \(message)")
            completion(.success(message))
        }
    }

    private func finishFailure(_ message: String, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.main.async {
            self.stage = .failed
            self.stageDetail = message
            self.isBusy = false
            self.append("✗ \(message)")
            completion(.failure(ADBError.connectionFailed(message)))
        }
    }

    private func resetLog() {
        DispatchQueue.main.async { self.log.removeAll() }
    }

    private func append(_ line: String) {
        DispatchQueue.main.async {
            let stamp = String(format: "%.3f", Date().timeIntervalSince1970)
            self.log.append("\(stamp)  \(line)")
            if self.log.count > 200 { self.log.removeFirst() }
        }
    }
}
