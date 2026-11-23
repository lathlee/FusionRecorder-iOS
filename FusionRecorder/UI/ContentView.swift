//
//  ContentView.swift
//  FusionRecorder
//
//  界面结构（0.5.3 视觉重做，功能与 0.5.2 一致）：
//    顶部品牌行 → 预览卡 → 主按钮 + 两颗次按钮 → 连接状态卡 → 折叠的调试与参数
//
//  0.5.3 的三处行为修正：
//    1. **没连上眼镜就不显示预览**。以前 FrameStore 启动时会把上一次抓的两帧
//       （或内置样例）读回来，眼镜连不上时界面照样有画面，看起来像「已连接」，
//       于是把排查方向引到「IP 不对」。现在没有真实帧就只显示占位。
//    2. 眼镜名字只显示从设备读到的 `ro.product.model`（ARGlasses），
//       不再回落到写死的「玄景」——这台根本不是玄景。
//    3. 「本机 IP」只显示局域网私有地址（RFC1918）。以前会把 VPN 的
//       16.2.0.0 虚拟接口地址显示出来，误导判断。
//
//  预览仍然是「成片同源」：两帧真实画面交给同一个 FusionCompositor 渲染，
//  参数只有一份（fusionParams），预览与录制共用。
//

import Foundation
import SwiftUI
import UIKit
import PhotosUI
import Photos
import CoreGraphics

struct ContentView: View {
    /// 回到前台就重新读一次本机地址：iOS 的「本地网络」权限框是异步弹的，
    /// 用户点完「允许」再切回来，这里才能读到刚被放行的局域网地址。
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var session = RecorderSession()
    @StateObject private var frames = FrameStore()
    /// 全自动部署编排器（View 持有以观察状态，注入 session 共用同一实例）
    @StateObject private var orchestrator = CaptureOrchestrator()
    @State private var autoBusy = false

    /// 调试/参数区是否展开（默认收起）
    @State private var showAdvanced = false
    @State private var showLog = false
    @State private var showSaveDone = false
    @State private var showProbeNote = false
    @State private var currentComposite: UIImage?
    @State private var saveNote = ""
    @State private var screenPicker: PhotosPickerItem?
    @State private var cameraPicker: PhotosPickerItem?
    /// 本机局域网 IP（只在「局域网私有地址」里挑，见 GlassesDiscovery.lanIP）
    @State private var lanIP = ""
    /// `getifaddrs` 实际枚举到的 IPv4 条数（不含 loopback）。
    /// 0 意味着 iOS 根本没把局域网接口暴露给本 App —— 那不是「显示问题」，
    /// 而是连扫描都会必然失败的真故障，必须明确报警。
    @State private var rawInterfaceCount = 0

    // iPhone 端连接（交接包 §5：POC_PC_IP / POC_SCREEN_PORT / POC_CAM_PORT）
    @AppStorage("host") private var host = "192.168.101.133"
    @AppStorage("screenPort") private var screenPort = "9114"
    @AppStorage("cameraPort") private var cameraPort = "9115"

    // 采集参数（默认值取自 MainActivity.loadPrefsIntoUi）
    @AppStorage("cameraIndex") private var cameraIndex = 0
    // 默认 640×480：相机流源就是 640×480，选 1280/1920 只是把同样的像素放大，
    // 却让逐像素合成算力翻 4~9 倍——真机实测会拖垮写帧导致卡顿。需要高清再手动调高。
    @AppStorage("resolutionIndex") private var resolutionIndex = 0
    @AppStorage("fpsIndex") private var fpsIndex = 2
    @AppStorage("bitrateIndex") private var bitrateIndex = 2
    @AppStorage("rotateIndex") private var rotateIndex = 0
    @AppStorage("durationIndex") private var durationIndex = 3

    // 叠加效果（范围/默认值取自 MainActivity.setSlider 与 OverlayConfig）
    @AppStorage("alpha") private var alpha = 0.55
    @AppStorage("scale") private var scale = 0.55
    @AppStorage("offsetX") private var offsetX = 0.0
    @AppStorage("offsetY") private var offsetY = 0.06
    @AppStorage("additive") private var additive = 0.35
    @AppStorage("corner") private var corner = 0.10
    @AppStorage("edge") private var edge = 0.12
    @AppStorage("brightness") private var brightness = 1.0
    @AppStorage("contrast") private var contrast = 1.0
    @AppStorage("crop") private var crop = 0.06

    /// 0.5.0：成片音量倍数（1.0 = 原始音量）。只影响**之后**合成的新片。
    @AppStorage("audioVolume") private var audioVolume = 1.0

    /// ★ 唯一一份参数：预览与录制共用
    private var fusionParams: FusionParams {
        let size = FusionParams.canvasSize(forResolutionIndex: resolutionIndex)
        var p = FusionParams()
        p.canvasWidth = size.width
        p.canvasHeight = size.height
        p.rotation = FusionParams.degrees(forRotationIndex: rotateIndex)
        p.alpha = alpha
        p.scale = scale
        p.offsetX = offsetX
        p.offsetY = offsetY
        p.additive = additive
        p.corner = corner
        p.edgeFade = edge
        p.brightness = brightness
        p.contrast = contrast
        p.crop = crop
        p.audioVolume = audioVolume
        return p
    }

    /// 参数 / 帧来源 / 帧版本任一变化都触发重新合成
    private var renderToken: String {
        "\(fusionParams.fingerprint)|rev\(frames.revision)|\(frames.origin.rawValue)"
    }

    private var canvasRatio: CGFloat {
        CGFloat(fusionParams.canvasWidth) / CGFloat(max(1, fusionParams.canvasHeight))
    }

    private var statusText: String {
        if session.isRunning {
            return "离线录制中 \(session.recordingElapsed)s：眼镜本地录两路 mp4 和一条音轨，停止后自动传回 iPhone 合成。"
        }
        return "预览 = 成片同源：两帧真实画面经同一合成器渲染，画布 \(fusionParams.canvasWidth)×\(fusionParams.canvasHeight)。"
    }

    /// 眼镜 IP → 连线方式。iPhone 开热点时眼镜的地址固定落在 172.20.10.0/28。
    private var linkKind: String {
        let ip = connectionIP
        if ip.isEmpty || ip == "—" { return "未连接" }
        if ip.hasPrefix("172.20.10.") { return "热点" }
        return "局域网"
    }

    private var connectionIP: String {
        orchestrator.glassesIP ?? (host.isEmpty ? "—" : host)
    }

    /// 只显示设备自报的型号；没读到就说没读到，不编名字。
    private var glassesName: String {
        orchestrator.deviceModel.isEmpty ? "未识别到眼镜" : orchestrator.deviceModel
    }

    private var isLinked: Bool {
        !orchestrator.linkLost && (orchestrator.isConnected || orchestrator.stage == .ready)
    }

    var body: some View {
        ZStack {
            Palette.bgGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    header
                    previewCard
                    actionButtons
                    connectionCard
                    advancedToggle
                    if showAdvanced { advancedPanel }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 30)
            }

            if session.offlinePhase == .recording {
                RecordingOverlay(elapsed: session.recordingElapsed,
                                 onStop: { session.stop() })
                .ignoresSafeArea()
            }

            if session.offlinePhase == .stopping
                || session.offlinePhase == .pulling
                || session.offlinePhase == .composing
                || session.offlinePhase == .saving {
                OfflineProgressOverlay(phase: session.offlinePhase,
                                       progress: session.offlineProgress,
                                       detail: session.phaseDetail)
                .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            session.frameStore = frames
            session.orchestrator = orchestrator
            session.update(params: fusionParams)
            refreshLanIP()
            // 0.5.6：主动去碰一次局域网 —— 否则 iOS 永远不给这个 App 建
            // 「本地网络」权限项，【设置 → 隐私与安全性 → 本地网络】里就永远没它。
            GlassesDiscovery.shared.requestLocalNetworkPermission()
            // 权限框是异步的，给它 1.5 秒再读一次接口地址
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { refreshLanIP() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { refreshLanIP() }
        }
        .onChange(of: fusionParams) { newValue in
            session.update(params: newValue)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                GlassesDiscovery.shared.requestLocalNetworkPermission()
                refreshLanIP()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { refreshLanIP() }
            }
        }
        .onChange(of: orchestrator.glassesIP) { newValue in
            // 眼镜换地址了（WiFi ↔ 热点）就把新地址写回去，
            // 否则 host 还是旧值，预览/录制会拿着废地址去连。
            if let ip = newValue, !ip.isEmpty, ip != host { host = ip }
            refreshLanIP()
        }
        // 掉线：清预览 + 让界面马上改成「已断开」，不等人去点任何按钮
        .onChange(of: orchestrator.linkLost) { lost in
            if lost {
                frames.clear()
                session.appendUser("眼镜连接已断开（换了网络 / IP 变了 / 眼镜睡了）")
            }
        }
        // 断开就清掉预览：留着旧画面会让人误以为还连着
        .onChange(of: orchestrator.isConnected) { connected in
            if !connected { frames.clear() }
            refreshLanIP()
        }
        .onChange(of: session.finishedMovieURL) { url in
            if url != nil { showSaveDone = true }
        }
        .onChange(of: session.recordError) { error in
            if error != nil { showSaveDone = true }
        }
        .sheet(isPresented: $showSaveDone) {
            SaveDoneSheet(movieURL: session.finishedMovieURL,
                          errorMessage: session.recordError,
                          onPlay: { openPhotos() },
                          onRetry: session.canRetryTransfer ? {
                showSaveDone = false
                session.retryTransfer()
            } : nil,
                          onClose: {
                showSaveDone = false
                session.clearRecordResult()
            })
                .presentationDetents([.medium])
        }
        .alert("检测屏幕采集", isPresented: $showProbeNote) {
            Button("好", role: .cancel) { }
        } message: {
            Text("v0.5 离线录制：眼镜本地分别录屏幕、相机两路 mp4 和一条麦克风音轨，不依赖 WiFi 实时推流，因此不会因链路抖动冻结。录制时只给计时；停止后自动传回，iPhone 按绝对时间戳对齐、按短的那路裁剪、把音轨并进成片并保存到相册。")
        }
    }

    // MARK: - 顶部品牌行

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("融合录制")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Palette.title)
                Text("眼镜画面 · 屏幕叠加 · 一次成片")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.hint)
            }
            Spacer(minLength: 8)
            statusPill
        }
        .padding(.top, 4)
    }

    private var statusPill: some View {
        let running = session.isRunning
        let connecting = orchestrator.isBusy
        let lost = orchestrator.linkLost
        let color: Color = running ? Palette.danger
            : (connecting ? Palette.accent
               : (lost ? Palette.warn : (isLinked ? Palette.green : Palette.hint)))
        let text: String = running ? "录制中 \(session.recordingElapsed)s"
            : (connecting ? "连接中"
               : (lost ? "已断开" : (isLinked ? "已就绪" : "未连接")))
        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.8), radius: 4)
            Text(text)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.25), lineWidth: 1))
    }

    // MARK: - 预览卡

    private var previewCard: some View {
        Group {
            if frames.hasFrames {
                FusionPreview(frames: frames, params: fusionParams,
                              token: renderToken, exported: $currentComposite)
            } else {
                previewPlaceholder
            }
        }
        .aspectRatio(canvasRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(frames.hasFrames ? Palette.strokeStrong : Palette.stroke, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) { previewChip }
        .overlay(alignment: .bottomTrailing) { canvasBadge }
        .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 10)
    }

    private var previewChip: some View {
        HStack(spacing: 5) {
            Image(systemName: frames.hasFrames ? "play.rectangle.fill" : "eyeglasses")
                .font(.system(size: 9, weight: .bold))
            Text(frames.hasFrames ? "成片预览" : "无信号")
                .font(.system(size: 10.5, weight: .semibold))
        }
        .foregroundStyle(frames.hasFrames ? Palette.title : Palette.hint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(10)
    }

    private var canvasBadge: some View {
        Text("\(fusionParams.canvasWidth)×\(fusionParams.canvasHeight)")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Palette.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(10)
    }

    /// 没连上 / 还没抓帧时的占位。★ 绝不在这里回落到旧画面。
    private var previewPlaceholder: some View {
        ZStack {
            LinearGradient(colors: [Palette.card, Palette.bg],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Palette.accent.opacity(0.14))
                        .frame(width: 62, height: 62)
                    if orchestrator.isBusy {
                        ProgressView().tint(Palette.accent)
                    } else {
                        Image(systemName: "eyeglasses")
                            .font(.system(size: 25, weight: .medium))
                            .foregroundStyle(Palette.accent)
                    }
                }

                Text(placeholderTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.title)

                Text(placeholderDetail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.hint)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 26)

                if !orchestrator.isBusy {
                    Button(action: autoDeploy) {
                        Text(orchestrator.stage == .failed ? "重试连接" : "连接眼镜")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Palette.accentGradient)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            .padding(16)
        }
    }

    private var placeholderTitle: String {
        if orchestrator.isBusy { return "正在连接眼镜…" }
        if orchestrator.stage == .failed { return "连接失败" }
        return "尚未连接眼镜"
    }

    private var placeholderDetail: String {
        if orchestrator.isBusy {
            return "点「连接眼镜」开始握手（这副眼镜不会弹授权框）"
        }
        if orchestrator.stage == .failed {
            return orchestrator.stageDetail.isEmpty ? "点下方重试连接" : orchestrator.stageDetail
        }
        if lanIP.isEmpty {
            return "点「连接眼镜」——眼镜 IP 已预填，会直连试一次\n（这副眼镜不弹 USB 授权框，也不需要本机 IP）"
        }
        return "连接后点「刷新预览」抓一帧真实画面\n没抓过帧就不显示旧画面"
    }

    // MARK: - 三颗主按钮

    private var actionButtons: some View {
        VStack(spacing: 9) {
            Button(action: toggleRecording) {
                HStack(spacing: 7) {
                    Image(systemName: session.isRunning ? "stop.fill" : "record.circle")
                        .font(.system(size: 15, weight: .bold))
                    Text(session.isRunning ? "停止录制" : "开始录制")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(session.isRunning ? AnyShapeStyle(Palette.recordGradient)
                                              : AnyShapeStyle(Palette.accentGradient))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: (session.isRunning ? Color.red : Palette.accent).opacity(0.35),
                        radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)

            HStack(spacing: 9) {
                secondaryButton(title: "打开相册", icon: "photo.on.rectangle") {
                    openPhotos()
                }
                secondaryButton(title: session.previewBusy ? "抓取中" : "刷新预览",
                                icon: "arrow.triangle.2.circlepath",
                                busy: session.previewBusy) {
                    refreshPreview()
                }
                .disabled(session.previewBusy)
            }

            if !session.previewNote.isEmpty {
                Text(session.previewNote)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
            }
        }
    }

    private func secondaryButton(title: String, icon: String, busy: Bool = false,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if busy {
                    ProgressView().scaleEffect(0.55).tint(Palette.label)
                } else {
                    Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                }
                Text(title).font(.system(size: 13.5, weight: .medium))
            }
            .foregroundStyle(Palette.label)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Palette.field)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 连接状态卡

    private var connectionCard: some View {
        SurfaceCard(padding: 14) {
            VStack(spacing: 11) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(isLinked ? Palette.green : Palette.hint)
                        .frame(width: 8, height: 8)
                        .shadow(color: (isLinked ? Palette.green : Color.clear).opacity(0.8), radius: 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(glassesName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.title)
                            .lineLimit(1)
                        Text(deviceLine)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Palette.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    Text(linkKind)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(isLinked ? Palette.section : Palette.hint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background((isLinked ? Palette.section : Palette.hint).opacity(0.12))
                        .clipShape(Capsule())
                }

                if let warning = networkWarning {
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.warn)
                        Text(warning)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.warn)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(9)
                    .background(Palette.warn.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Divider().overlay(Palette.stroke)

                HStack(spacing: 8) {
                    Image(systemName: lanIP.isEmpty ? "link" : "wifi")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.hint)
                    Text(lanIPLabel)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.secondary)
                    Spacer(minLength: 6)
                    Button(action: rescan) {
                        HStack(spacing: 4) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 10, weight: .bold))
                            Text("重新扫描")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Palette.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(orchestrator.isBusy)
                }
            }
        }
    }

    private var deviceLine: String {
        var parts: [String] = []
        if connectionIP != "—" { parts.append("IP \(connectionIP)") }
        if !orchestrator.deviceSerial.isEmpty { parts.append("SN \(orchestrator.deviceSerial)") }
        if parts.isEmpty { parts.append("尚未连接") }
        return parts.joined(separator: "  ·  ")
    }

    /// 手动填的优先。用户在「连接参数」里填了 IP，界面就得认，否则填了等于没填。
    private var effectiveLocalIP: String {
        lanIP
    }

    private var lanIPLabel: String {
        // 0.5.7：只显示真正的局域网私有地址。
        // 之前会把 VPN 的虚拟网卡当成「本机 IP」显示成 16.2.0.0 —— 用户看到
        // 「识别的IP不对」，其实那个地址对离线录制毫无用处，显示它纯属误导。
        if !lanIP.isEmpty { return "本机 " + lanIP }
        return "眼镜直连 · 无需本机 IP"
    }

    /// 只有真正会让录制失败的情况才报警。
    ///
    /// 0.5.5 及以前这里只要读不到局域网 IP 就甩一句
    /// 「去 设置 → 隐私与安全性 → 本地网络 打开」—— 而那个开关根本不存在
    /// （App 从没主动访问过局域网，系统从没建过这项），属于把人往死路上指。
    private var networkWarning: String? {
        if orchestrator.isBusy { return nil }
        // 已经连上了还报警，只会让人以为出了问题
        if orchestrator.isConnected { return nil }
        let ip = effectiveLocalIP
        // 一个接口都枚举不到：这不是显示问题，扫描也一定会失败
        if rawInterfaceCount == 0 && ip.isEmpty {
            return "iOS 没把本 App 的局域网访问放开（读不到任何接口地址）。"
                + "把 App 切到后台再切回来，会弹「允许访问本地网络」，点允许"
        }
        let g = connectionIP
        if !ip.isEmpty, g != "—", !GlassesDiscovery.sameSubnet(ip, g) {
            return "本机(\(ip)) 与眼镜(\(g)) 不在同一网段：让两者连同一个 WiFi，或开热点让眼镜连 iPhone"
        }
        return nil
    }

    // MARK: - 折叠开关

    private var advancedToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showAdvanced.toggle() }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.section)
                Text(showAdvanced ? "收起调试与参数" : "调试与参数")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.title)
                Spacer()
                if !showAdvanced {
                    Text("参数 · 日志 · 调试")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.hint)
                }
                Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.hint)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 折叠区（提示语 / 调试 / 参数 / 日志）

    private var advancedPanel: some View {
        VStack(spacing: 12) {
            SurfaceCard {
                Text(statusText)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // ---- 真实帧来源 ----
            blockCard("真实帧来源", icon: "photo.stack") {
                VStack(alignment: .leading, spacing: 9) {
                    Text("\(frames.origin.rawValue)：\(frames.note)")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.label)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        miniButton("用眼镜实时画面") { refreshPreview() }
                        miniButton("内置样例帧") { frames.resetToSample() }
                    }
                    HStack(spacing: 8) {
                        if frames.hasSavedFrames {
                            miniButton("恢复上次两帧") { frames.restoreSaved() }
                        }
                        PhotosPicker(selection: $screenPicker, matching: .images) {
                            miniLabel("导入屏幕帧")
                        }
                        .onChange(of: screenPicker) { item in
                            loadPicked(item, isScreen: true)
                        }
                        PhotosPicker(selection: $cameraPicker, matching: .images) {
                            miniLabel("导入相机帧")
                        }
                        .onChange(of: cameraPicker) { item in
                            loadPicked(item, isScreen: false)
                        }
                        miniButton("保存合成帧") { saveCurrentFrame() }
                    }
                    if !saveNote.isEmpty {
                        Text(saveNote)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.section)
                    }
                }
            }

            // ---- 全自动部署 ----
            blockCard("部署与连接", icon: "antenna.radiowaves.left.and.right") {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 6) {
                        Text(orchestrator.stage.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(orchestrator.stage == .failed ? Palette.danger
                                             : (isLinked ? Palette.green : Palette.secondary))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Palette.field)
                            .clipShape(Capsule())
                        Text(orchestrator.stageDetail)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.hint)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 8) {
                        miniButton(orchestrator.isBusy ? "部署中…" : "① 部署采集端") { autoDeploy() }
                        miniButton(orchestrator.isBusy ? "请稍候" : "② 全自动录制") { autoRecord() }
                    }

                    Text("① 只装好眼镜端（扫 5555 → ADB 授权 → push APK/JAR → 授权相机与麦克风）；② 部署完直接开录。首次 ADB 需在眼镜上点「允许调试」。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.hint)
                        .fixedSize(horizontal: false, vertical: true)

                    if !orchestrator.log.isEmpty {
                        logBox(orchestrator.log.suffix(10).map { $0 }, color: Palette.secondary)
                    }
                }
            }

            // ---- 调试 ----
            blockCard("调试", icon: "wrench.and.screwdriver") {
                VStack(alignment: .leading, spacing: 9) {
                    actionRow("检测屏幕采集（约 20 秒，先看这条能不能通）") { showProbeNote = true }
                    actionRow(showLog ? "隐藏运行日志" : "查看运行日志") { showLog.toggle() }
                    if showLog {
                        Text("阶段 \(session.offlinePhase.rawValue) · \(session.phaseDetail) · 日志 \(session.log.count) 条")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(Palette.hint)
                        logBox(session.log, color: Palette.danger)
                    }
                }
            }

            // ---- 采集参数 ----
            blockCard("采集参数", icon: "camera.aperture") {
                VStack(spacing: 7) {
                    pickerRow("摄像头", selection: $cameraIndex, options: Options.cameras)
                    pickerRow("分辨率", selection: $resolutionIndex, options: Options.resolutions)
                    pickerRow("帧率", selection: $fpsIndex, options: Options.fps)
                    pickerRow("码率", selection: $bitrateIndex, options: Options.bitrates)
                    pickerRow("画面旋转校正", selection: $rotateIndex, options: Options.rotations)
                    pickerRow("自动停止", selection: $durationIndex, options: Options.durations)
                }
            }

            // ---- 叠加效果 ----
            blockCard("叠加效果", icon: "square.on.square") {
                VStack(spacing: 9) {
                    sliderRow("屏幕透明度", value: $alpha, range: 0.0...1.0)
                    sliderRow("屏幕占比", value: $scale, range: 0.2...0.95)
                    sliderRow("水平位置", value: $offsetX, range: -0.5...0.5)
                    sliderRow("垂直位置", value: $offsetY, range: -0.5...0.5)
                    sliderRow("发光强度", value: $additive, range: 0.0...1.0)
                    sliderRow("圆角", value: $corner, range: 0.0...0.5)
                    sliderRow("边缘渐隐", value: $edge, range: 0.0...0.5)
                    sliderRow("屏幕亮度", value: $brightness, range: 0.5...1.8)
                    sliderRow("摄像头对比度", value: $contrast, range: 0.6...1.6)
                    sliderRow("裁掉右侧", value: $crop, range: 0.0...0.15)
                    Text("悬浮球占了屏幕右侧一小条，把它裁掉即可让成品里看不到悬浮球。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.hint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // ---- 声音 ----
            blockCard("声音", icon: "waveform") {
                VStack(spacing: 9) {
                    sliderRow("合成音量（倍数）", value: $audioVolume, range: 0.0...3.0)
                    HStack(spacing: 8) {
                        miniButton("0.7×") { audioVolume = 0.7 }
                        miniButton("1.0×") { audioVolume = 1.0 }
                        miniButton("1.5×") { audioVolume = 1.5 }
                    }
                    Text("只影响之后合成的新成片，相册里已有的文件不会被改动。2.0× 以上是数字放大，环境噪声也会一起变大。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.hint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // ---- 连接参数 ----
            blockCard("连接参数", icon: "network") {
                VStack(spacing: 9) {
                    Text("眼镜无线 ADB 默认 5555。换网络（WiFi ↔ 热点）后眼镜 IP 会变，"
                        + "点「重新扫描」会自动找；找不到就在这里填。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.hint)
                        .fixedSize(horizontal: false, vertical: true)
                    fieldRow("眼镜 IP", text: $host, decimal: true)
                    HStack(spacing: 8) {
                        Button("恢复默认 IP") {
                            host = Self.defaultHost
                            session.appendUser("眼镜 IP 已恢复默认 \(Self.defaultHost)")
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Palette.accent)
                        .buttonStyle(.plain)
                        Spacer()
                        Text("当前 \(orchestrator.glassesIP ?? "未连接")")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(Palette.hint)
                    }
                    fieldRow("屏幕流端口", text: $screenPort, decimal: false)
                    fieldRow("相机流端口", text: $cameraPort, decimal: false)
                }
            }
        }
    }

    // MARK: - 组件

    private func blockCard<C: View>(_ title: String, icon: String,
                                    @ViewBuilder content: () -> C) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.section)
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.title)
                    Spacer()
                }
                content()
            }
        }
    }

    private func logBox(_ lines: [String], color: Color) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(8)
        }
        .frame(maxHeight: 170)
        .background(Palette.bg.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func actionRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.label)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.hint)
            }
            .padding(.horizontal, 11)
            .frame(height: 40)
            .background(Palette.field)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func miniButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { miniLabel(title) }
            .buttonStyle(.plain)
    }

    private func miniLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11.5))
            .foregroundStyle(Palette.label)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(Palette.field)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func pickerRow(_ title: String, selection: Binding<Int>, options: [String]) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.label)
            Spacer(minLength: 6)
            Picker("", selection: selection) {
                ForEach(0..<options.count, id: \.self) { index in
                    Text(options[index]).tag(index)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(Palette.section)
        }
        .padding(.horizontal, 11)
        .frame(height: 42)
        .background(Palette.field)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func fieldRow(_ title: String, text: Binding<String>, decimal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Palette.hint)
            TextField(title, text: text)
                .font(.system(size: 13.5, design: .monospaced))
                .foregroundStyle(Palette.title)
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 11)
                .frame(height: 40)
                .background(Palette.field)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.label)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.section)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Palette.field)
                    .clipShape(Capsule())
            }
            Slider(value: value, in: range)
                .tint(Palette.accent)
        }
    }

    // MARK: - 行为

    private func refreshLanIP() {
        let ip = GlassesDiscovery.shared.displayLocalIP(for: orchestrator.glassesIP ?? host) ?? ""
        if ip != lanIP { lanIP = ip }
        let count = GlassesDiscovery.shared.localIPv4().count
        if count != rawInterfaceCount { rawInterfaceCount = count }
    }

    /// 候选地址：手填的 → 这副眼镜的常用地址 → 热点下常见的 172.20.10.2。
    /// 扫描时先探这几个（每个 0.45 秒），命中就不用扫整个 /24。
    private var knownCandidates: [String] {
        var list: [String] = []
        let typed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        for ip in [typed, Self.defaultHost, GlassesDiscovery.hotspotGlassesIP] where !ip.isEmpty {
            if !list.contains(ip) { list.append(ip) }
        }
        return list
    }

    /// 重新扫描：**真的去扫**（0.5.7 之前这个按钮其实只是拿手填/存着的 IP 直连，
    /// 根本没扫，所以换了网络之后点它永远不会找到眼镜）。
    private func rescan() {
        guard !orchestrator.isBusy else { return }
        session.appendUser("重新扫描：先探 \(knownCandidates.joined(separator: " / "))，再扫本机网段…")
        autoScan()
    }

    /// 这副眼镜的地址（DHCP 长期稳定在 .133）。留作「重新扫描」的兜底，
    /// 也方便手滑清空后一键恢复。
    private static let defaultHost = "192.168.101.133"

    /// 刷新预览：抓屏幕上真实的一帧 + 相机拍一张，合成后立刻显示。
    private func refreshPreview() {
        // ★ 0.5.7：本地已经连上的那个 IP 优先。
        // 以前用 `host`（AppStorage 里的手填值），换了网络之后它是旧的，
        // 于是「明明录制能跑，刷新预览却连不上」。
        let target = orchestrator.glassesIP ?? host
        let given = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !given.isEmpty else {
            session.appendUser("还没有眼镜 IP：先点「连接眼镜」，或在连接参数里填一个")
            return
        }
        session.refreshPreview(host: given) { result in
            if case .failure(let error) = result {
                session.appendUser("刷新预览失败：\(error.localizedDescription)")
            }
        }
    }

    private func loadPicked(_ item: PhotosPickerItem?, isScreen: Bool) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    frames.applyImported(data: data, isScreen: isScreen)
                    saveNote = isScreen ? "屏幕帧已替换" : "相机帧已替换"
                }
            }
        }
    }

    private func saveCurrentFrame() {
        guard let image = currentComposite else {
            saveNote = "合成帧还没生成"
            return
        }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                saveNote = success ? "当前合成帧已保存到相册，可与成片逐帧比对"
                                  : "保存失败：\(error?.localizedDescription ?? "无权限")"
            }
        }
    }

    private func autoDeploy() {
        // 「连接眼镜」也走扫描：手填的 IP 只作为**候选**先探一次（0.45 秒），
        // 探通就直接用它部署；探不通继续扫本机 /24。
        // 以前这里是「拿着 AppStorage 里的 IP 直接连」——换了网络后那个 IP 是废的，
        // 于是等 40 秒握手超时才报错，看着就像「IP 不对 / 连不上」。
        autoScan()
    }

    private func autoScan() {
        guard !autoBusy else {
            session.appendUser("部署流程还在执行中，请稍等")
            return
        }
        autoBusy = true
        orchestrator.run(host: nil, iphoneHostIP: nil,
                         extraCandidates: knownCandidates) { [self] result in
            DispatchQueue.main.async {
                self.autoBusy = false
                self.refreshLanIP()
                if case .failure(let error) = result {
                    self.session.appendUser("部署失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func autoRecord() {
        // ★ 这里以前是两个静默 return：按钮点了完全没反应、也不留日志。
        // 真机排查时最难受的就是这种「什么都不发生」，所以一律打日志。
        guard !session.isRunning else {
            session.appendUser("已经在录制中，先点「停止录制」")
            return
        }
        guard !autoBusy else {
            session.appendUser("上一个部署/启动流程还没结束，请稍等十几秒再点")
            return
        }
        autoBusy = true
        session.clearRecordResult()
        session.update(params: fusionParams)
        // 已连上：直接用当前地址（编排器会复用那条连接）。
        // 没连上：host 传 nil + 候选地址，让编排器扫 —— 传死 IP 只会白等 40 秒超时。
        let target = orchestrator.isConnected ? orchestrator.glassesIP : nil
        session.appendUser("点「开始录制」：开始走离线链路（部署 → 眼镜本地录制）")
        session.startAuto(host: target,
                          candidates: knownCandidates,
                          iphoneHostIP: nil,
                          screenPort: UInt16(screenPort) ?? 9114,
                          cameraPort: UInt16(cameraPort) ?? 9115) { [self] result in
            DispatchQueue.main.async {
                self.autoBusy = false
                switch result {
                case .success:
                    // 录制页由 session.offlinePhase 驱动，markRecordingStarted 已切换
                    break
                case .failure(let error):
                    self.session.appendUser("全自动启动失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func toggleRecording() {
        if session.isRunning {
            session.stop()
        } else {
            // 主「开始录制」按钮与「② 全自动录制」走同一条离线链路：
            // 部署采集端 → 眼镜本地录两路 mp4 + 音轨 → 计时 → 停止 → ADB pull → 离线合成。
            autoRecord()
        }
    }

    private func openPhotos() {
        if let url = URL(string: "photos-redirect://") {
            UIApplication.shared.open(url)
        }
    }
}
