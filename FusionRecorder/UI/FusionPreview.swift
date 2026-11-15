//
//  FusionPreview.swift
//  FusionRecorder
//
//  交接包 03_验证素材/融合录屏_单帧.png 的视觉复刻：暗相机背景 + 中央半透明
//  「设置」页面板。面板由主界面的叠加效果滑杆实时驱动，用来标定
//  alpha / scale / offset / corner / additive / brightness。
//
//  注意：这是 SwiftUI 绘制的**示意预览**，不是真实视频帧。
//  v0.2 接上 VideoToolbox + Metal 双路管线后换成真实画面。
//

import SwiftUI

struct FusionPreview: View {
    var alpha: Double
    var scale: Double
    var offsetX: Double
    var offsetY: Double
    var corner: Double
    var additive: Double
    var brightness: Double

    private let rows = ["网络和互联网", "已连接的设备", "应用和通知", "电池", "显示", "定时开关机"]
    private let rowColors: [Color] = [.blue, .green, .orange, .teal, .yellow, .blue]

    private func panelWidth(_ fullWidth: CGFloat) -> CGFloat {
        let clamped = min(max(scale, 0.2), 0.95)
        return fullWidth * CGFloat(clamped) * 0.92
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 相机流背景（PoC 实测镜头朝下时偏暗的紫黑色）
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.05, blue: 0.07),
                        Color(red: 0.02, green: 0.02, blue: 0.03)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // 屏幕流叠加层（半透明设置页）
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Text("设置")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.18))
                        Spacer()
                        Text("16:28")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(red: 0.25, green: 0.25, blue: 0.28))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.80, green: 0.80, blue: 0.82).opacity(0.55))

                    ForEach(0..<rows.count, id: \.self) { index in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(rowColors[index])
                                .frame(width: 11, height: 11)
                            Text(rows[index])
                                .font(.system(size: 9))
                                .foregroundStyle(Color(red: 0.18, green: 0.18, blue: 0.20))
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .frame(height: geo.size.height * 0.06)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: panelWidth(geo.size.width),
                       height: panelWidth(geo.size.width) * 0.62)
                .background(Color(red: 0.72, green: 0.72, blue: 0.74)
                    .opacity(alpha * min(max(brightness, 0.5), 1.8)))
                .clipShape(RoundedRectangle(cornerRadius: CGFloat(corner) * 60))
                .shadow(color: Color.white.opacity(additive * 0.35),
                        radius: CGFloat(additive) * 18)
                .offset(x: CGFloat(offsetX) * geo.size.width * 0.5,
                        y: CGFloat(-offsetY) * geo.size.height * 0.5)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}
