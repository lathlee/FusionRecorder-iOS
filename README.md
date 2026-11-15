# FusionRecorder-iOS · 融合录屏 iPhone 端

**独立仓库**：只放「融合录屏」的 iPhone 端，不与任何其他应用共用仓库、共用 workflow、共用产物分支。其他应用继续在各自原仓库开发，本仓库的任何提交与 force-push 都不会碰到它们；工程内也没有任何其他应用的代码或引用。

依据：`FusionRecorder_融合录屏_交接包/交接说明_HANDOFF.md` §0 / §3 / §7。

---

## 现状（v0.1 骨架，诚实标注）

| 模块 | 状态 |
|---|---|
| SwiftUI 界面（眼镜 IP / 双路端口 / 开始停止 / 状态 / 日志） | 已实现 |
| ADB 帧 CNXN / AUTH / OPEN / WRTE / OKAY / CLSE 编解码 + TCP 收发 | 已实现；**RSA 认证路径留 TODO**（需真机联调授权界面） |
| 双路裸 TCP H264 接收 + Annex-B NAL 拆包（处理半包/粘包） | 已实现 |
| VideoToolbox 双路解码 / Metal 合成 / VideoToolbox 编码 / 写相册 | **类型骨架 + TODO**，真实管线未接 |
| 双路流 pts 封装 | 未做（交接包 §7 待办 1，正式合成的前提） |

**这一版的目标是把云端编译链路跑通、产出未签名 `.ipa`**，不是交付可出片的成品。功能在本仓库里逐版迭代，不污染其他应用。

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
- 取产物：`https://raw.githubusercontent.com/<owner>/FusionRecorder-iOS/ios-build/ci-logs/FusionRecorder-0.1.0-unsigned.ipa`
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

版本号唯一来源是 `project.yml` 的 `MARKETING_VERSION`（当前 `0.1.0`）。改版本只改这一处，workflow 与 IPA 文件名都从它读取。
