//
//  Theme.swift
//  FusionRecorder
//
//  配色与选项全部照抄交接包 01_主项目_FusionRecorder/app/src/main/res/layout/activity_main.xml
//  以及 MainActivity.java 里的 WIDTHS / FPS_LIST / BITRATES / ROTATIONS / DURATIONS。
//

import SwiftUI

enum Palette {
    static let bg = Color(red: 0.071, green: 0.071, blue: 0.071)            // #121212 主界面
    static let title = Color(red: 0.878, green: 0.878, blue: 0.878)         // #E0E0E0 标题
    static let secondary = Color(red: 0.620, green: 0.620, blue: 0.620)     // #9E9E9E 状态
    static let section = Color(red: 0.502, green: 0.796, blue: 0.769)        // #80CBC4 分组标题
    static let label = Color(red: 0.741, green: 0.741, blue: 0.741)          // #BDBDBD 控件标签
    static let hint = Color(red: 0.459, green: 0.459, blue: 0.459)           // #757575 说明
    static let danger = Color(red: 0.937, green: 0.604, blue: 0.604)         // #EF9A9A 日志
    static let field = Color(red: 0.145, green: 0.145, blue: 0.145)          // 下拉/输入框底
    static let card = Color(red: 0.118, green: 0.118, blue: 0.118)            // #1E1E1E 弹窗
    static let green = Color(red: 0.298, green: 0.686, blue: 0.314)          // #4CAF50 录制中
    static let accent = Color(red: 0.039, green: 0.518, blue: 1.0)           // #0A84FF 主按钮
    static let recordingBg = Color(red: 0.063, green: 0.075, blue: 0.102)    // #10131A
}

enum Options {
    static let cameras = ["自动选择", "摄像头 0", "摄像头 1"]
    static let resolutions = ["640 × 480", "1280 × 720", "1920 × 1080"]
    static let fps = ["15 fps", "24 fps", "30 fps"]
    static let bitrates = ["2 Mbps", "4 Mbps", "6 Mbps", "10 Mbps"]
    static let rotations = ["0°", "90°", "180°", "270°"]
    static let durations = ["不限", "15 秒", "30 秒", "60 秒", "5 分钟"]
}
