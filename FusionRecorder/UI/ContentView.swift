//
//  ContentView.swift
//  FusionRecorder
//
//  0.5.0 界面重排：
//    · 预览画面置顶；
//    · 预览正下方固定三颗按钮：开始录制 / 打开相册 / 刷新预览；
//    · 再下面一条「当前连接」信息栏（眼镜名称、局域网/热点、IP）；
//    · 其余全部（提示语、调试按钮、参数设置、日志）**默认收起**，点一下才展开。
//
//  刷新预览 = 让眼镜抓一帧真实屏幕（screencap）+ 一帧真实相机（APK 的 SNAPSHOT 动作），
//  各解成 CGImage 后交给 FrameStore，预览立刻用同一份 FusionCompositor 重新合成。
//  所以调滑杆看到的画面，就是成片会长的样子。
//
//  参数仍旧只有一个来源（fusionParams）：预览与录制共用，禁止两处各自解释。
//

import Foundation
import SwiftUI
import UIKit
import PhotosUI
import Photos
import CoreGraphics

struct ContentView: View {
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

    // iPhone 端连接（交接包 §5：POC_PC_IP / POC_SCREEN_PORT / POC_CAM_PORT）
    @AppStorage("host") private var host = "192.168.101.133"
    @AppStorage("iphoneHostIP") private var iphoneHostIP = ""
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

    private var statusText: String {
        if session.isRunning {
            return "离线录制中 \(session.recordingElapsed)s：眼镜本地录两路 mp4 和一条音轨，停止后自动传回 iPhone 合成。"
        }
        return "预览 = 成片同源：两帧真实画面经同一合成器渲染，画布 \(fusionParams.canvasWidth)×\(fusionParams.canvasHeight)。"
    }

    /// 眼镜 IP → 连线方式。iPhone 开热点时眼镜的地址固定落在 172.20.10.0/28。
    private var linkKind: String {
        let ip = orchestrator.glassesIP ?? host
        if ip.hasPrefix("172.20.10.") { return "热点" }
        if ip.isEmpty { return "未连接" }
        return "局域网"
    }

    private var connectionIP: String {
        orchestrator.glassesIP ?? (host.isEmpty ? "—" : host)
    }

    private var glassesName: String {
        if !orchestrator.deviceModel.isEmpty { return orchestrator.deviceModel }
        return "玄景 AR 眼镜"
    }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("融合录制")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Palette.title)
                        Spacer()
                        if session.isRunning {
                            Text("● 录制中 \(session.recordingElapsed)s")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.green)
                        }
                    }

                    // ---- 真实帧合成预览（成片宽高比，画布 = 成片分辨率）----
                    FusionPreview(frames: frames, params: fusionParams,
                                  token: renderToken, exported: $currentComposite)
                        .aspectRatio(Double(fusionParams.canvasWidth) / Double(fusionParams.canvasHeight),
                                     contentMode: .fit)
                        .padding(.top, 10)

                    // ---- 预览下方固定三颗按钮 ----
                    HStack(spacing: 8) {
                        Button(action: toggleRecording) {
                            Text(session.isRunning ? "停止录制" : "开始录制")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(session.isRunning ? Palette.danger : Palette.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)

                        Button(action: openPhotos) {
                            Text("打开相册")
                                .font(.system(size: 14))
                                .foregroundStyle(Palette.title)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Palette.field)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)

                        Button(action: refreshPreview) {
                            HStack(spacing: 4) {
                                if session.previewBusy {
                                    ProgressView().scaleEffect(0.6)
                                }
                                Text(session.previewBusy ? "抓取中" : "刷新预览")
                                    .font(.system(size: 14))
                            }
                            .foregroundStyle(Palette.title)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Palette.field)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(session.previewBusy)
                    }
                    .padding(.top, 10)

                    if !session.previewNote.isEmpty {
                        Text(session.previewNote)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.secondary)
                            .padding(.top, 6)
                    }

                    // ---- 当前连接 ----
                    connectionBar
                        .padding(.top, 10)

                    // ---- 折叠开关：其余全部内容默认收起 ----
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { showAdvanced.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                            Text(showAdvanced ? "收起调试与参数" : "展开调试与参数")
                                .font(.system(size: 13))
                            Spacer()
                            if !showAdvanced {
                                Text("参数 · 日志 · 调试")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Palette.hint)
                            }
                        }
                        .foregroundStyle(Palette.section)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(Palette.field)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)

                    if showAdvanced {
                        advancedPanel
                    }
                }
                .padding(12)
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
        }
        .onChange(of: fusionParams) { newValue in
            session.update(params: newValue)
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

    // MARK: - 当前连接栏

    private var connectionBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(orchestrator.stage == .ready ? Palette.green
                      : (orchestrator.glassesIP == nil ? Palette.hint : Palette.accent))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text(glassesName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.title)
                    .lineLimit(1)
                Text(connectionDetail)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(linkKind)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.section)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Palette.field)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var connectionDetail: String {
        var parts = ["IP \(connectionIP)"]
        if !orchestrator.deviceSerial.isEmpty {
            parts.append("SN \(orchestrator.deviceSerial)")
        }
        if let phone = orchestrator.iphoneIP, !phone.isEmpty {
            parts.append("本机 \(phone)")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - 折叠区（提示语 / 调试 / 参数 / 日志）

    private var advancedPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(statusText)
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondary)
                .padding(.top, 10)

            HStack {
                Text("融合效果预览 · 真实帧合成")
                Spacer()
                Text("预览 = 成片同源")
                    .foregroundStyle(Palette.section)
            }
            .font(.system(size: 11))
            .foregroundStyle(Palette.hint)
            .padding(.top, 8)

            // ---- 真实帧来源 ----
            sectionTitle("真实帧来源")
            Text(frames.origin.rawValue + "：" + frames.note)
                .font(.system(size: 11))
                .foregroundStyle(Palette.label)
                .padding(.top, 2)

            HStack(spacing: 8) {
                smallButton("恢复内置真实帧") { frames.resetToSample() }
                smallButton("用眼镜实时画面") { refreshPreview() }
            }
            .padding(.top, 6)

            HStack(spacing: 8) {
                PhotosPicker(selection: $screenPicker, matching: .images) {
                    smallLabel("导入屏幕帧")
                }
                .onChange(of: screenPicker) { item in
                    loadPicked(item, isScreen: true)
                }
                PhotosPicker(selection: $cameraPicker, matching: .images) {
                    smallLabel("导入相机帧")
                }
                .onChange(of: cameraPicker) { item in
                    loadPicked(item, isScreen: false)
                }
                smallButton("保存当前合成帧") { saveCurrentFrame() }
            }
            .padding(.top, 6)

            if !saveNote.isEmpty {
                Text(saveNote)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.section)
                    .padding(.top, 4)
            }

            // ---- 调试按钮 ----
            sectionTitle("调试")
            actionButton("检测屏幕采集（约 20 秒，先看这条能不能通）") {
                showProbeNote = true
            }
            .padding(.top, 6)

            actionButton(showLog ? "隐藏崩溃日志" : "查看崩溃日志") {
                showLog.toggle()
            }
            .padding(.top, 6)

            if showLog {
                VStack(alignment: .leading, spacing: 2) {
                    Text("阶段 \(session.offlinePhase.rawValue) · \(session.phaseDetail) · 日志 \(session.log.count) 条")
                        .font(.system(size: 11, design: .monospaced))
                    ForEach(session.log, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
                .foregroundStyle(Palette.danger)
                .padding(.top, 8)
            }

            sectionTitle("全自动录制（v0.5 离线架构）")
            Text("状态：\(orchestrator.stage.rawValue) — \(orchestrator.stageDetail)")
                .font(.system(size: 11))
                .foregroundStyle(orchestrator.stage == .failed ? Palette.danger : Palette.section)
            HStack(spacing: 8) {
                smallButton(orchestrator.isBusy ? "部署中…" : "① 自动部署采集端") {
                    autoDeploy()
                }
                smallButton(orchestrator.isBusy ? "请稍候" : "② 全自动录制") {
                    autoRecord()
                }
            }
            .padding(.top, 6)
            Text("① 只装好眼镜端（扫 5555 → ADB 授权 → push APK/JAR → 授权相机与麦克风）；② 部署完直接开录。眼镜 IP 留空自动扫描。首次 ADB 需在眼镜上点「允许调试」。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.hint)
                .padding(.top, 4)
            if !orchestrator.log.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    Text("部署日志：").font(.system(size: 11, design: .monospaced))
                    ForEach(orchestrator.log.suffix(8), id: \.self) { line in
                        Text(line).font(.system(size: 10, design: .monospaced))
                    }
                }
                .foregroundStyle(Palette.danger)
                .padding(.top, 6)
            }

            // ---- 采集参数 ----
            sectionTitle("采集参数")
            pickerRow("摄像头", selection: $cameraIndex, options: Options.cameras)
            pickerRow("摄像头分辨率（决定输出视频分辨率）", selection: $resolutionIndex, options: Options.resolutions)
            pickerRow("帧率", selection: $fpsIndex, options: Options.fps)
            pickerRow("码率", selection: $bitrateIndex, options: Options.bitrates)
            pickerRow("画面旋转校正（画面方向不对时调整）", selection: $rotateIndex, options: Options.rotations)
            pickerRow("自动停止", selection: $durationIndex, options: Options.durations)

            // ---- 叠加效果 ----
            sectionTitle("叠加效果")
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
                .font(.system(size: 11))
                .foregroundStyle(Palette.hint)
                .padding(.top, 4)

            // ---- 声音 ----
            sectionTitle("声音")
            sliderRow("合成音量（倍数）", value: $audioVolume, range: 0.0...3.0)
            HStack(spacing: 8) {
                smallButton("还原 1.0×") { audioVolume = 1.0 }
                smallButton("小声一点 0.7×") { audioVolume = 0.7 }
                smallButton("放大 1.5×") { audioVolume = 1.5 }
            }
            .padding(.top, 6)
            Text("只影响**之后**合成的新成片，相册里已有的文件不会被改动。"
                 + "2.0× 以上是数字放大，环境噪声也会一起变大。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.hint)
                .padding(.top, 4)

            // ---- iPhone 端连接 ----
            sectionTitle("iPhone 端连接")
            Text("眼镜无线 ADB 默认 5555；iPhone 开热点时眼镜连热点。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.hint)
                .padding(.top, 2)
            fieldRow("眼镜 IP", text: $host, decimal: true)
            fieldRow("iPhone IP（留空自动）", text: $iphoneHostIP, decimal: true)
            fieldRow("屏幕流端口（9114）", text: $screenPort, decimal: false)
            fieldRow("相机流端口（9115）", text: $cameraPort, decimal: false)

            Text("成片在相册里；预览帧可单独保存下来核对。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.hint)
                .padding(.top, 14)
        }
    }

    // MARK: - 控件

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Palette.section)
            .padding(.top, 16)
    }

    private func actionButton(_ title: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: prominent ? 16 : 14))
                .foregroundStyle(prominent ? Color.white : Palette.title)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(prominent ? Palette.accent : Palette.field)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func smallButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            smallLabel(title)
        }
        .buttonStyle(.plain)
    }

    private func smallLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11))
            .foregroundStyle(Palette.title)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Palette.field)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func pickerRow(_ title: String, selection: Binding<Int>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Palette.label)
            Picker("", selection: selection) {
                ForEach(0..<options.count, id: \.self) { index in
                    Text(options[index]).tag(index)
                }
            }
            .pickerStyle(.menu)
            .tint(Palette.title)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Palette.field)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.top, 6)
    }

    private func fieldRow(_ title: String, text: Binding<String>, decimal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Palette.label)
            TextField(title, text: text)
                .font(.system(size: 14))
                .foregroundStyle(Palette.title)
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .autocorrectionDisabled()
                .padding(8)
                .background(Palette.field)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.top, 6)
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.label)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Palette.section)
            }
            Slider(value: value, in: range)
                .tint(Palette.accent)
        }
        .padding(.top, 8)
    }

    // MARK: - 行为

    /// 刷新预览：抓屏幕上真实的一帧 + 相机拍一张，合成后立刻显示。
    private func refreshPreview() {
        let given = host.trimmingCharacters(in: .whitespacesAndNewlines)
        session.refreshPreview(host: given.isEmpty ? nil : given) { result in
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
        guard !autoBusy else {
            session.appendUser("部署流程还在执行中，请稍等")
            return
        }
        autoBusy = true
        let given = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let localIP = iphoneHostIP.trimmingCharacters(in: .whitespacesAndNewlines)
        orchestrator.run(host: given.isEmpty ? nil : given,
                         iphoneHostIP: localIP.isEmpty ? nil : localIP) { [self] result in
            DispatchQueue.main.async {
                self.autoBusy = false
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
        let given = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let localIP = iphoneHostIP.trimmingCharacters(in: .whitespacesAndNewlines)
        session.appendUser("点「开始录制」：开始走离线链路（部署 → 眼镜本地录制）")
        session.startAuto(host: given.isEmpty ? nil : given,
                          iphoneHostIP: localIP.isEmpty ? nil : localIP,
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
