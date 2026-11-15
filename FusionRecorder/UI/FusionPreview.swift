//
//  FusionPreview.swift
//  FusionRecorder
//
//  v0.1.2：预览不再是 SwiftUI 手绘示意图，而是**真实像素合成结果**。
//
//  输入：FrameStore 里的两帧真实画面（PoC 真实解码帧 / 眼镜抓帧 / 相册导入）
//  处理：FusionCompositor.render —— 与录制写帧时调用的完全是同一个函数
//  输出：UIImage，按成片宽高比显示（画布尺寸 = 成片分辨率，不是控件尺寸）
//
//  参数 token 一变就异步重算，用 generation 丢弃过期任务，滑杆拖动不卡 UI。
//

import SwiftUI
import CoreGraphics
import UIKit

struct FusionPreview: View {
    let frames: FrameStore
    let params: FusionParams
    /// 由 ContentView 用 params.fingerprint + frames.revision 拼成，变化即重算
    let token: String
    @Binding var exported: UIImage?

    @State private var image: UIImage?
    @State private var generation = 0
    @State private var failed = false

    var body: some View {
        ZStack {
            Palette.field

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if failed {
                VStack(spacing: 6) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 26))
                        .foregroundStyle(Palette.hint)
                    Text("真实帧未就绪")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.hint)
                }
            } else {
                ProgressView()
                    .tint(Palette.section)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear { recompute() }
        .onChange(of: token) { _ in recompute() }
    }

    private func recompute() {
        generation += 1
        let mine = generation
        let snapshot = params
        let screen = frames.screenImage
        let camera = frames.cameraImage

        guard let screen = screen, let camera = camera else {
            DispatchQueue.main.async {
                self.failed = true
                self.image = nil
                self.exported = nil
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let cg = FusionCompositor.render(screen: screen, camera: camera, params: snapshot)
            let result = cg.map { UIImage(cgImage: $0) }
            DispatchQueue.main.async {
                guard mine == self.generation else { return }  // 丢弃过期结果
                self.failed = result == nil
                self.image = result
                self.exported = result
            }
        }
    }
}
