//
//  RecordingViews.swift
//  FusionRecorder
//
//  0.4.0 离线录制架构：
//    · 录制中只给计时（不需要实时预览，也不再看 NAL 计数）
//    · 停止后给「收尾 / 传输 / 合成 / 保存」统一进度条
//

import SwiftUI
import UIKit

struct RecordingOverlay: View {
    /// 已录制秒数
    var elapsed: Int
    var onStop: () -> Void

    private var timeText: String {
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        ZStack {
            Palette.recordingBg.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("● 录制中")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Palette.green)

                Text(timeText)
                    .font(.system(size: 64, weight: .light, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text("眼镜正在本地分别录制屏幕与相机画面")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.label)

                Text("离线录制不依赖 WiFi 实时推流，画面不会因链路抖动冻结。\n录制期间无需预览，点停止后自动传回 iPhone 合成并保存相册。")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button(action: onStop) {
                    Text("停止录制")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 11)
                        .background(Palette.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.top, 18)
            }
            .padding(20)
        }
    }
}

struct OfflineProgressOverlay: View {
    var phase: OfflinePhase
    var progress: Double
    var detail: String

    private var title: String {
        switch phase {
        case .stopping: return "正在收尾写文件"
        case .pulling:  return "正在传输录制文件"
        case .composing: return "正在离线合成"
        case .saving:   return "正在保存相册"
        default:        return "处理中"
        }
    }

    private var isIndeterminate: Bool { phase == .stopping || phase == .saving }

    var body: some View {
        ZStack {
            Palette.recordingBg.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 14) {
                if isIndeterminate {
                    ProgressView()
                        .scaleEffect(1.4)
                }
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                if !isIndeterminate {
                    ProgressView(value: progress, total: 1)
                        .tint(Palette.accent)
                        .padding(.horizontal, 36)
                    Text(String(format: "%.0f%%", progress * 100))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Palette.section)
                }

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Text("录制完成后需要一点时间传输和合成，请保持 App 在前台。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.hint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
        }
    }
}

struct SaveDoneSheet: View {
    var movieURL: URL?
    var errorMessage: String?
    var onPlay: () -> Void
    var onClose: () -> Void

    private var isSuccess: Bool { movieURL != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isSuccess ? "录制完成" : "写入失败")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)

            if isSuccess {
                Text("成片已按两路绝对时间戳对齐、按短的那路裁剪，并保存到相册。画面与预览同源，预览里调好的参数就是成片里的效果。\n\n文件：\(movieURL?.lastPathComponent ?? "")")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.label)
            } else {
                Text(errorMessage ?? "未知错误")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.label)
                Text("常见原因：眼镜端 mp4 没写完、ADB pull 失败、或两个视频没有可对齐的帧。可看主界面日志排查。")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.secondary)
            }

            if isSuccess {
                Button(action: onPlay) {
                    Text("打开相册")
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
                .padding(.top, 10)
            }

            Button(action: onClose) {
                Text("完成")
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .padding(.top, 2)
        }
        .padding(22)
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(24)
    }
}
