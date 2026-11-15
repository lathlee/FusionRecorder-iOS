//
//  ContentView.swift
//  FusionRecorder
//
//  v0.1：把「眼镜 IP / 双路端口 / 起停 / 状态 / 日志」做出来，
//  让云端编译出来的 .ipa 装上就能连链路、看到数据流。
//

import SwiftUI

struct ContentView: View {
    @StateObject private var session = RecorderSession()
    @State private var host = "192.168.101.133"
    @State private var screenPort = "9114"
    @State private var cameraPort = "9115"

    var body: some View {
        NavigationStack {
            Form {
                Section("眼镜（无线 ADB）") {
                    TextField("眼镜 IP", text: $host)
                        .keyboardType(.decimalPad)
                        .autocorrectionDisabled()
                    Text("无线 ADB 默认 5555；iPhone 开热点时眼镜连热点。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("双路 H264 裸 TCP") {
                    TextField("屏幕流端口", text: $screenPort)
                        .keyboardType(.numberPad)
                    TextField("相机流端口", text: $cameraPort)
                        .keyboardType(.numberPad)
                }

                Section("状态") {
                    LabeledContent("运行", value: session.isRunning ? "采集中" : "已停止")
                    LabeledContent("屏幕 NAL", value: "\(session.screenNALCount)")
                    LabeledContent("相机 NAL", value: "\(session.cameraNALCount)")
                    Button {
                        if session.isRunning {
                            session.stop()
                        } else {
                            session.start(host: host,
                                          screenPort: UInt16(screenPort) ?? 9114,
                                          cameraPort: UInt16(cameraPort) ?? 9115)
                        }
                    } label: {
                        Text(session.isRunning ? "停止录制" : "开始录制")
                    }
                }

                Section("日志") {
                    ForEach(session.log, id: \.self) { line in
                        Text(line)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text("v0.1 编译链路骨架：ADB / 双路流已实现，VideoToolbox + Metal 合成管线待接，详见 README。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("融合录屏")
        }
    }
}
