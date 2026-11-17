//
//  RecordingViews.swift
//  FusionRecorder
//
//  复刻交接包 activity_recording.xml（录制中全屏页）与
//  activity_save_done.xml（录制完成弹窗）的深色布局。
//  v0.2：录制中显示「已写入 N 帧」；完成后显示成片状态（真机写相册待联调）。
//

import SwiftUI
import CoreGraphics
import UIKit

struct RecordingOverlay: View {
    /// 录制中的实时合成帧：与写进成片的是同一帧（RecordingCompositor 输出）
    var image: CGImage?
    var frameCount: Int = 0
    var onStop: () -> Void

    var body: some View {
        ZStack {
            Palette.recordingBg.ignoresSafeArea()

            VStack(spacing: 14) {
                if let image = image {
                    Image(uiImage: UIImage(cgImage: image))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    Text("上面的合成帧 = 正在写入成片的画面（同一合成器 / 同一参数）")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.section)
                        .multilineTextAlignment(.center)
                }
                Text("● 录制中")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Palette.green)

                Text("已写入 \(frameCount) 帧 · 按真实 pts 对齐")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.label)

                Text("v0.2：双路 H264 解码 + SEI pts 对齐 + 逐帧 H264 编码写 mp4。\n成片与预览共用同一合成器，参数效果一致。")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.secondary)
                    .multilineTextAlignment(.center)

                Button(action: onStop) {
                    Text("停止录制")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Palette.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
            }
            .padding(16)
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
            Text(isSuccess ? "录制完成" : ("写入失败" ))
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)

            if isSuccess {
                Text("成片已按真实时间戳写入并保存到相册。合成画面与预览同源，预览里调好的参数就是成片里的效果。\n\n文件：\(movieURL?.lastPathComponent ?? "")")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.label)
            } else {
                Text(errorMessage ?? "未知错误")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.label)
                Text("常见原因：没有收到两路帧、编码器初始化失败、或相册权限未开。可看主界面日志排查。")
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
