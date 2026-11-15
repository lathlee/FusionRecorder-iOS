//
//  RecordingViews.swift
//  FusionRecorder
//
//  复刻交接包 activity_recording.xml（录制中全屏页）与
//  activity_save_done.xml（录制完成弹窗）的深色布局。
//  文案按 iPhone 端 v0.1 的真实能力做了诚实标注，不假装已出片。
//

import SwiftUI

struct RecordingOverlay: View {
    var onStop: () -> Void

    var body: some View {
        ZStack {
            Palette.recordingBg.ignoresSafeArea()

            VStack(spacing: 14) {
                Text("● 录制中")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Palette.green)

                Text("摄像头正在录制")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.label)

                Text("v0.1 骨架：双路 H264 裸 TCP 接收已接入，\nMetal 实时合成与写相册待 v0.2")
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

            Text("v0.1 骨架未产出成片；VideoToolbox 编码与写相册待 v0.2 接入。")
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
