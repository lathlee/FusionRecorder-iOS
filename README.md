# FusionRecorder-iOS · 融合录屏 iPhone 端

**独立仓库**：只放「融合录屏」的 iPhone 端，不与任何其他应用共用仓库、共用 workflow、共用产物分支。其他应用继续在各自原仓库开发，本仓库的任何提交与 force-push 都不会碰到它们；工程内也没有任何其他应用的代码或引用。

依据：`FusionRecorder_融合录屏_交接包/交接说明_HANDOFF.md` §0 / §3 / §7。

---

## 现状（v0.1.2，诚实标注）

| 模块 | 状态 |
|---|---|
| SwiftUI 界面（严格复刻 `activity_main.xml`） | 已实现 |
| **真实帧融合预览**（PoC 真实解码帧 / 眼镜抓帧 / 相册导入） | 已实现，滑杆实时重算 |
| **预览与成片同源合成**（`FusionCompositor` 单一入口） | 已实现，逐像素复刻 Android shader |
| 双路裸 TCP H264 接收 + Annex-B NAL 拆包（半包/粘包） | 已实现 |
| VideoToolbox 单帧解码（用于从眼镜抓帧、录制中实时合成帧） | 已实现 |
| 逐帧 `VTCompressionSession` 编码 + `AVAssetWriter` 写 mp4 到相册 | **仍待 v0.2** |
| 双路流 pts 封装 / ADB RSA 真机授权 | 未做（交接包 §7 待办 1 / 2，正式出片的前提） |

**v0.1.2 解决的是「预览调好了，成片却变样」这个具体问题**：预览不再是手绘示意图，
而是两张真实画面经**与录制完全相同的合成函数 + 同一份参数 + 同一个画布分辨率**渲染出的像素。
还没做的是把合成帧逐帧编码成 mp4（v0.2），但那条路径已经预留为直接消费合成器的输出，
不会、也不需要重写合成逻辑。

## 界面（按交接文件复刻）

界面**不是自行设计**，逐项照抄交接包里 Android 端的原型：

| 来源 | 复刻内容 |
|---|---|
| `01_主项目_FusionRecorder/app/src/main/res/layout/activity_main.xml` | 深色 `#121212` 滚动页、标题「融合录制」、状态行、4 个按钮（开始录制 / 打开相册 / 检测屏幕采集 / 查看崩溃日志）、红色等宽日志区、「采集参数」6 个下拉、「叠加效果」10 条滑杆、底部取文件说明 |
| `MainActivity.java` | 下拉选项（640×480 / 1280×720 / 1920×1080、15/24/30 fps、2/4/6/10 Mbps、0/90/180/270°、不限/15s/30s/60s/5min）与默认值（720p / 30fps / 6Mbps / 60s）；滑杆范围与默认值（透明度 0.55、占比 0.55、水平 0、垂直 0.06、发光 0.35、圆角 0.10、渐隐 0.12、亮度 1.0、对比度 1.0、裁右侧 0.06） |
| `activity_recording.xml` / `activity_save_done.xml` | 「● 录制中」全屏页与「录制完成」弹窗 |
| `app/src/main/res/values/strings.xml` | 应用显示名「融合录制」 |
| `03_验证素材/三路对照_相机_屏幕_融合.png` | 融合结果观感核对基准：暗相机背景 + 中央半透明设置页面板 |
| `01_主项目_FusionRecorder/.../CompositorRenderer.java` | **合成算法**：相机层 contrast、屏幕层 tint/brightness/圆角 mask/边缘渐隐/加色混合、cropRight 几何、ONE / ONE_MINUS_SRC_ALPHA 混合 |

所有参数用 `@AppStorage` 实时保存、下次打开保持（对齐 Android `Prefs` 行为）。iPhone 端必需的「眼镜 IP / 两路端口」与「真实帧来源」单独成组，原型的分组结构和配色不变。

## 预览 = 成片同源（v0.1.2 核心）

之前版本的预览是 SwiftUI 手绘示意图，`offsetY` 方向、`scale` 系数、圆角半径、发光算法都和
Android 合成器对不上，而录制侧又是空 TODO —— 这正是「预览里调 OK、成片里天差地别」的根因。
这一版从机制上杜绝它：

```text
10 条滑杆 + 分辨率/旋转  ──>  FusionParams（唯一一份数值）
                                   │
                 ┌─────────────────┴─────────────────┐
                 v                                   v
         FusionPreview（预览）            RecordingCompositor（录制）
                 └────── FusionCompositor.render ──────┘
                 （同一函数 / 同一画布 1280×720 / 同一像素运算）
                                   │
                    预览显示的图 == 写进成片的那一帧
```

- **几何全部归一化**到成片画布 `canvasWidth×canvasHeight`，预览控件在屏幕上多大都不影响；
  没有 `0.92` 倍缩放、`60px` 圆角这类随控件尺寸漂移的魔法数。
- **预览渲染尺寸 = 成片分辨率**，得到的就是成片那一帧，只是被缩小显示。
- 「摄像头分辨率」「画面旋转校正」也进入合成，预览里同样看得见变化。
- `tools/render_preview.py` 是同一算法的 Python 参考实现，可离线重算任意参数下的成片帧，
  用来第三方核对；`preview/` 下有已生成的效果图与参数变化对照。

**真实帧三路来源**：① 内置交接包 `02_PoC_双路流` 的 `dual_cam.h264` / `dual_screen.h264`
各解出的真实一帧（离线即可看到真实融合效果）；② 点「从眼镜抓两帧」，连 9114 / 9115
各用 VideoToolbox 解一帧替换；③ 从相册导入两张真实截图。选中帧持久化，重启仍在。
「保存当前合成帧」把这一帧存进相册，方便日后与成片逐帧比对。

> **诚实标注**：逐帧编码写 mp4 仍是 v0.2；ADB RSA 授权未联调，所以「从眼镜抓帧」需要
> 眼镜端推流服务已经启动，连不上时用相册导入同样能标定参数。录制中页面显示的实时合成帧
> 已经由同一个合成器产出，不是占位图。

## 目标架构

```text
眼镜屏幕 --(shell uid 虚拟屏镜像 + MediaCodec)--> H264 --裸 TCP 9114-->\
                                                                       iPhone 合成 -> mp4 -> 相册
眼镜相机 --(App CAMERA + MediaCodec)-----------> H264 --裸 TCP 9115-->/
                    ^
                    +-- 无线 ADB 5555 只用于启动/授权/push/保活，视频流不挤进 adb 协议
```

iPhone 开热点时眼镜连热点，`POC_PC_IP` 对应 iPhone 在该网段地址（通常 `172.20.10.1`）。

## 云端编译（本机没有 Xcode）

云端沙箱同样是 Linux，没有 Xcode；真正编译 iOS 的是 **GitHub Actions 免费 macOS runner**：

- workflow：`.github/workflows/build-ipa.yml`
- `xcodegen generate` 生成 `.xcodeproj` → `xcodebuild -sdk iphoneos CODE_SIGNING_ALLOWED=NO` → 打 `Payload/` zip 成未签名 `.ipa`
- 产物与日志推到本仓库的 `ios-build` 分支（匿名可读），同时上传 Actions artifact（保留 30 天）
- 取产物：`https://raw.githubusercontent.com/<owner>/FusionRecorder-iOS/ios-build/ci-logs/FusionRecorder-0.1.2-unsigned.ipa`
- 侧载签名：SideStore / AltStore + 免费 Apple ID，7 天续签（交接包 §7 待办 6）

## 推送与云端编译

**前置**：已在 GitHub 网页创建**空的公开仓库 `lathlee/FusionRecorder-iOS`**（不勾 README / .gitignore / LICENSE）。

**关于令牌（实测结论）**：GitHub 连接器发的是 `ghu_` 开头的 **GitHub App 用户令牌**，
读仓库没问题，但 `POST /git/blobs`、`PUT /contents/...`、`POST /user/repos` 一律返回
`403 Resource not accessible by integration` —— **它只能读，不能写内容**。
沙箱里 `github.com:443` 直连也不通、`gh` 未登录、git 凭据助手无凭据，所以没有第二条自动写入通道。
推送需要 **classic PAT**：[https://github.com/settings/tokens](https://github.com/settings/tokens)
→ Generate new token (classic) → 勾 `repo` + `workflow`。

三种方式，任选其一：

**A. 全自动（把 PAT 交给 WorkBuddy，或自己在沙箱跑）**

```bash
export GITHUB_TOKEN=ghp_xxxxx
./scripts/cloud_build.sh
```

脚本复用独立仓库 → 经 `api.github.com` 的 Git Data API 一次性提交到 `main`（只触发一次构建）
→ 若 push 没触发则 `workflow_dispatch` 兜底 → 等 Actions → 把 `.ipa` 下载到 `ci-logs/` 并校验 zip。
Token 只走环境变量，不写进仓库文件。

**B. 本机一键（不想把 token 发给任何人）**

```bash
python scripts/local_build.py          # Windows: python scripts\local_build.py
# 或 GITHUB_TOKEN=ghp_xxxxx python scripts/local_build.py
```

只用 Python 标准库，不需要 git / Xcode / gh CLI。脚本提示粘贴 PAT（**不回显、不落盘**），
自动完成推送、等编译、下载 `.ipa`；失败时直接打印 CI 错误摘要，把摘要发回来改代码再跑一次即可。
已经用网页上传过文件时用 `python scripts/local_build.py --no-push`，只查结果 + 取产物。

**C. 零 token（网页上传）**

仓库页 → **Add file → Upload files**，把工程目录里的文件拖进去，
**必须包含隐藏目录 `.github/workflows/build-ipa.yml`**，排除 `.git/` 与 `ci-logs/`，
commit 到 `main` 即自动触发 Actions。产物与日志推到本仓库的 `ios-build` 分支，匿名可读。

> 无论用哪种，写操作都只落在这一个独立仓库；其他应用所在仓库零改动。

## 本地有 Mac 时

```bash
brew install xcodegen && xcodegen generate && open FusionRecorder.xcodeproj
```

## 版本

版本号唯一来源是 `project.yml` 的 `MARKETING_VERSION`（当前 `0.1.2`）。改版本只改这一处，workflow 与 IPA 文件名都从它读取。

| 版本 | 内容 |
|---|---|
| 0.1.0 | 云端编译链路跑通，未签名 IPA 可侧载 |
| 0.1.1 | 界面按交接包 `activity_main.xml` 复刻，10 条滑杆齐备 |
| **0.1.2** | 预览换真实帧；预览与录制共用唯一合成器与参数；加入眼镜抓帧 / 相册导入 / 合成帧导出 |
