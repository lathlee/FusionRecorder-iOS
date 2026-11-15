//
//  RecordingViews.swift
//  FusionRecorder
//
//  复刻交接包 activity_recording.xml（录制中全屏页）与
//  activity_save_done.xml（录制完成弹窗）的深色布局。
//  文案按 iPhone 端 v0.1 的真实能力做了诚实标注，不假装已出片。
//

import SwiftUI
import CoreGraphics
import UIKit

struct RecordingOverlay: View {
    /// 录制中的实时合成帧：与写进成片的是同一帧（RecordingCompositor 输出）
    var image: CGImage?
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

                Text("摄像头正在录制")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.label)

                Text("v0.1.2：双路 H264 解码 + 真实像素合成已接入，\n逐帧编码写相册待 v0.2")
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
    var onPlay: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("录制完成")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)

            Text("v0.1.2 尚未产出 mp4 成片：合成帧已在录制中实时生成（与预览同源），VTCompressionSession 编码 + 写相册待 v0.2。")
                .font(.system(size: 13))
                .foregroundStyle(Palette.label)

            Button(action: onPlay) {
                Text("播放")
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.accent)
            .padding(.top, 10)

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
