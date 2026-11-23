//
//  Theme.swift
//  FusionRecorder
//
//  配色与选项。选项表照抄交接包 MainActivity 里的
//  WIDTHS / FPS_LIST / BITRATES / ROTATIONS / DURATIONS。
//
//  0.5.3 视觉重做：原来是「灰色面板 + 平按钮」的调试界面观感，
//  改成深色渐变底 + 卡片分层 + 强调色胶囊的状态标记：
//    · 背景走 #0B0D10 → #12151A 的轻微渐变，避免整屏死黑；
//    · 卡片用 #14181E，靠 1px 白 7% 描边分层，不再用大块灰底；
//    · 主色 #2F7BFF（动作），辅助 #6EE7D2（分组标题/数值），
//      警告 #FFB74D（网段不一致），录制 #FF5252。
//  类名沿用旧名，避免动到其它文件里的引用。
//

import SwiftUI

enum Palette {
    static let bg        = Color(red: 0.043, green: 0.051, blue: 0.063)   // #0B0D10
    static let bgBottom  = Color(red: 0.071, green: 0.082, blue: 0.098)   // #12151A
    static let card      = Color(red: 0.078, green: 0.094, blue: 0.118)   // #14181E
    static let field     = Color(red: 0.110, green: 0.133, blue: 0.165)   // #1C222A

    static let title     = Color(red: 0.949, green: 0.961, blue: 0.973)   // #F2F5F8
    static let label     = Color(red: 0.780, green: 0.808, blue: 0.839)   // #C7CED6
    static let secondary = Color(red: 0.655, green: 0.690, blue: 0.733)   // #A7B0BB
    static let hint      = Color(red: 0.424, green: 0.463, blue: 0.514)   // #6C7683

    static let section   = Color(red: 0.431, green: 0.906, blue: 0.824)   // #6EE7D2 分组标题
    static let accent    = Color(red: 0.184, green: 0.482, blue: 1.0)     // #2F7BFF 主按钮
    static let accentLo  = Color(red: 0.106, green: 0.365, blue: 0.902)   // 渐变下半
    static let danger    = Color(red: 1.0,   green: 0.420, blue: 0.420)   // #FF6B6B
    static let green     = Color(red: 0.204, green: 0.827, blue: 0.600)   // #34D399
    static let warn      = Color(red: 1.0,   green: 0.718, blue: 0.302)   // #FFB74D
    static let recordingBg = Color(red: 0.063, green: 0.075, blue: 0.102)

    /// 卡片描边（浅白细线，替代大块灰底做分层）
    static let stroke = Color.white.opacity(0.07)
    static let strokeStrong = Color.white.opacity(0.12)

    static var bgGradient: LinearGradient {
        LinearGradient(colors: [bg, bgBottom], startPoint: .top, endPoint: .bottom)
    }
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accentLo], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var recordGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 1.0, green: 0.353, blue: 0.353),
                                Color(red: 0.851, green: 0.161, blue: 0.216)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum Options {
    static let cameras = ["自动选择", "摄像头 0", "摄像头 1"]
    static let resolutions = ["640 × 480", "1280 × 720", "1920 × 1080"]
    static let fps = ["15 fps", "24 fps", "30 fps"]
    static let bitrates = ["2 Mbps", "4 Mbps", "6 Mbps", "10 Mbps"]
    static let rotations = ["0°", "90°", "180°", "270°"]
    static let durations = ["不限", "15 秒", "30 秒", "60 秒", "5 分钟"]
    /// 0.6.2 去黑底的两种算法：亮度键（保留对比、黑底全透）/ 滤色（更亮但更柔）
    static let keyModes = ["亮度键（推荐）", "滤色（更亮）"]
}

/// 通用卡片容器：圆角 + 细描边，全 App 统一一种卡片观感。
struct SurfaceCard<Content: View>: View {
    var padding: CGFloat
    var corner: CGFloat
    let content: Content

    init(padding: CGFloat = 14, corner: CGFloat = 18,
         @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.corner = corner
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 1)
            )
    }
}
