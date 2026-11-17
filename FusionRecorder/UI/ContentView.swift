//
//  ContentView.swift
//  FusionRecorder
//
//  布局严格复刻交接包 activity_main.xml（深色 #121212 → 标题「融合录制」→ 状态
//  → 4 按钮 → 崩溃日志 → 采集参数 6 下拉 → 叠加效果 10 滑杆）。
//  iPhone 端特有部分单独成组，不改原型视觉。
//
//  v0.2：录制打通「双路 H264 → SEI pts 对齐 → 合成 → H264 写 mp4 → 相册」，
//  录制完成页等写入回调再弹（不再假装成功）。
//  关键点：FusionParams 在下面由 10 条滑杆 + 2 个采集下拉组装成唯一一份，
//  同时喂给预览（FusionPreview）和录制（RecorderSession / RecordingCompositor）。
//  两条路径都调 FusionCompositor.render，因此预览里调好的参数就是成片里的效果。
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

    @State private var showLog = false
    @State private var showRecording = false
    @State private var showSaveDone = false
    @State private var isFinishing = false
    @State private var showProbeNote = false
    @State private var currentComposite: UIImage?
    @State private var saveNote = ""
    @State private var screenPicker: PhotosPickerItem?
    @State private var cameraPicker: PhotosPickerItem?

    // iPhone 端连接（交接包 §5：POC_PC_IP / POC_SCREEN_PORT / POC_CAM_PORT）
    @AppStorage("host") private var host = "192.168.101.133"
    @AppStorage("screenPort") private var screenPort = "9114"
    @AppStorage("cameraPort") private var cameraPort = "9115"

    // 采集参数（默认值取自 MainActivity.loadPrefsIntoUi）
    @AppStorage("cameraIndex") private var cameraIndex = 0
    @AppStorage("resolutionIndex") private var resolutionIndex = 1
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
        return p
    }

    /// 参数 / 帧来源 / 帧版本任一变化都触发重新合成
    private var renderToken: String {
        "\(fusionParams.fingerprint)|rev\(frames.revision)|\(frames.origin.rawValue)"
    }

    private var statusText: String {
        if session.isRunning {
            return "采集中：屏幕 NAL \(session.screenNALCount) / 相机 NAL \(session.cameraNALCount)；下方预览与录制中的合成帧使用同一套参数。"
        }
        return "预览 = 成片同源：两帧真实画面经同一合成器渲染，画布 \(fusionParams.canvasWidth)×\(fusionParams.canvasHeight)。拖动下方滑杆即刻更新。"
    }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("融合录制")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.title)

                    Text(statusText)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.secondary)
                        .padding(.top, 4)

                    // ---- 真实帧合成预览（成片宽高比，画布 = 成片分辨率）----
                    FusionPreview(frames: frames, params: fusionParams,
                                  token: renderToken, exported: $currentComposite)
                        .aspectRatio(Double(fusionParams.canvasWidth) / Double(fusionParams.canvasHeight),
                                     contentMode: .fit)
                        .padding(.top, 12)

                    HStack {
                        Text("融合效果预览 · 真实帧合成")
                        Spacer()
                        Text("预览 = 成片同源")
                            .foregroundStyle(Palette.section)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.hint)
                    .padding(.top, 4)

                    // ---- 真实帧来源（v0.1.2 新增）----
                    sectionTitle("真实帧来源")
                    Text(frames.origin.rawValue + "：" + frames.note)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.label)
                        .padding(.top, 2)

                    HStack(spacing: 8) {
                        smallButton(session.captureInProgress ? "抓帧中…" : "从眼镜抓两帧") {
                            session.captureFrames(host: host,
                                                  screenPort: UInt16(screenPort) ?? 9114,
                                                  cameraPort: UInt16(cameraPort) ?? 9115)
                        }
                        smallButton("恢复内置真实帧") { frames.resetToSample() }
                    }
                    .padding(.top, 6)

                    if !session.captureState.isEmpty && session.captureState != "未抓帧" {
                        Text(session.captureState)
                            .font(.system(size: 11))
                            .foregroundStyle(session.captureInProgress ? Palette.section : Palette.hint)
                            .padding(.top, 4)
                    }

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

                    Text("抓帧：眼镜端两路推流服务要先起来（9114 屏幕 / 9115 相机）。连不上时可直接从相册导入两张真实截图，参数照样实时生效。保存的合成帧可与日后成片逐帧比对。")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.hint)
                        .padding(.top, 4)

                    // ---- 原型 4 个按钮 ----
                    actionButton(session.isRunning ? "停止录制" : "开始录制", prominent: true) {
                        toggleRecording()
                    }
                    .padding(.top, 12)

                    actionButton("打开相册") { openPhotos() }
                        .padding(.top, 6)

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
                            Text("屏幕 NAL \(session.screenNALCount) · 相机 NAL \(session.cameraNALCount) · 日志 \(session.log.count) 条")
                                .font(.system(size: 11, design: .monospaced))
                            ForEach(session.log, id: \.self) { line in
                                Text(line)
                                    .font(.system(size: 11, design: .monospaced))
                            }
                        }
                        .foregroundStyle(Palette.danger)
                        .padding(.top, 8)
                    }

                    sectionTitle("采集参数")
                    pickerRow("摄像头", selection: $cameraIndex, options: Options.cameras)
                    pickerRow("摄像头分辨率（决定输出视频分辨率）", selection: $resolutionIndex, options: Options.resolutions)
                    pickerRow("帧率", selection: $fpsIndex, options: Options.fps)
                    pickerRow("码率", selection: $bitrateIndex, options: Options.bitrates)
                    pickerRow("画面旋转校正（画面方向不对时调整）", selection: $rotateIndex, options: Options.rotations)
                    pickerRow("自动停止", selection: $durationIndex, options: Options.durations)

                    sectionTitle("iPhone 端连接")
                    Text("眼镜无线 ADB 默认 5555；iPhone 开热点时眼镜连热点。")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.hint)
                        .padding(.top, 2)
                    fieldRow("眼镜 IP", text: $host, decimal: true)
                    fieldRow("屏幕流端口（9114）", text: $screenPort, decimal: false)
                    fieldRow("相机流端口（9115）", text: $cameraPort, decimal: false)

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

                    Text("取成片：相册（v0.2 接入 AVAssetWriter 后自动保存）；预览帧已可单独保存核对。")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.hint)
                        .padding(.top, 16)
                }
                .padding(12)
            }

            if showRecording {
                RecordingOverlay(image: session.livePreview,
                                 frameCount: session.recordedFrameCount,
                                 onStop: {
                    // v0.2：stop() 异步封装成片，等写入回调再弹完成页
                    session.stop()
                    isFinishing = true
                })
                .ignoresSafeArea()
            }

            if isFinishing {
                ZStack {
                    Palette.recordingBg.opacity(0.85).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("正在封装成片并保存相册…")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.label)
                    }
                }
                .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            session.frameStore = frames
            session.update(params: fusionParams)
        }
        .onChange(of: fusionParams) { newValue in
            session.update(params: newValue)
        }
        // 成片写入是异步的：只有拿到结果才收起录制页、弹完成页
        .onChange(of: session.finishedMovieURL) { url in
            if url != nil {
                isFinishing = false
                showRecording = false
                showSaveDone = true
            }
        }
        .onChange(of: session.recordError) { error in
            if error != nil && isFinishing {
                isFinishing = false
                showRecording = false
                showSaveDone = true
            }
        }
        .sheet(isPresented: $showSaveDone) {
            SaveDoneSheet(movieURL: session.finishedMovieURL,
                          errorMessage: session.recordError,
                          onPlay: { openPhotos() },
                          onClose: {
                showSaveDone = false
                session.clearRecordResult()
            })
                .presentationDetents([.medium])
        }
        .alert("检测屏幕采集", isPresented: $showProbeNote) {
            Button("好", role: .cancel) { }
        } message: {
            Text("v0.2：录制已接入真实 pts 对齐与 mp4 写入。点「开始录制」后同步收 9114/9115 两路，按时间戳配对合成并写入相册。ADB RSA 授权仍需真机联调；连不上时流接收不受影响。")
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

    private func toggleRecording() {
        if session.isRunning {
            session.stop()
            isFinishing = true
        } else {
            session.clearRecordResult()
            session.update(params: fusionParams)
            session.start(host: host,
                          screenPort: UInt16(screenPort) ?? 9114,
                          cameraPort: UInt16(cameraPort) ?? 9115)
            showRecording = true
        }
    }

    private func openPhotos() {
        if let url = URL(string: "photos-redirect://") {
            UIApplication.shared.open(url)
        }
    }
}
