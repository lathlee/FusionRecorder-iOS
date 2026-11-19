# 真机联调清单（眼镜到手后照着走）

> **适用版本**：iPhone `FusionRecorder 0.3.0`（未签名 IPA，SideStore 侧载） + 眼镜采集端 `fusion-capture.apk` / `screen-push.jar`（已打进 IPA，App 自动 push）。
> **这份清单解决什么**：沙箱已经把 ADB 协议、SEI pts、双路对齐、成片算法全部对拍过（33/33 契约断言通过，`python3 tools/integration_test.py` 可复现）。**剩下只有真机才能验的**：ROM 授权框、MediaCodec/Camera2 运行时、AVAssetWriter 写相册。按下面 7 步走，每步都有"预期"和"失败怎么办"，不用现场改代码。
> **总原则**：一次只验一个变量。先单独验两路流（用探针，绕开 iPhone），再验 iPhone 全自动部署，最后验成片。别一上来就点全自动录制——出问题分不清是哪一环。

---

## 准备：网络与工具

| 项 | 操作 | 预期 |
|---|---|---|
| 热点 | iPhone 开个人热点，眼镜连上（2.4G）。iPhone 关掉"最大兼容性"外的限制，确保局域网可见 | 眼镜拿到 `172.20.10.x` 地址 |
| 查 iPhone IP | iPhone 设置→无线局域网→连热点的设备旁点 ⓘ；或 App 部署日志会打印 | 记下 iPhone IP，如 `172.20.10.1` |
| 无线 ADB | 眼镜端开启无线 ADB（5555）。若需先 USB：`adb tcpip 5555` | `adb connect <眼镜IP>:5555` 通 |
| 电脑探针 | 一台与眼镜同网段的电脑，装 [platform-tools](https://developer.android.com/tools/releases/platform-tools)，从源码包取 `tools/stream_probe.py` | `python3 tools/stream_probe.py --help` 有输出 |

> ⚠️ **方向别搞反**：采集端启动命令里的 `host` 是 **iPhone 的 IP**（眼镜主动把流推给 iPhone 的 9114/9115 监听口），不是眼镜自己的 IP。全自动部署里 App 已自动填对；手动验流时自己填别填错。

---

## 第 1 步：ADB 授权（真机唯一未验项，先单独打通）

目的：确认这家定制 ROM 在收到 ADB PUBLICKEY 后**弹不弹授权框**。这是整个全自动链路的地基。

| 操作 | 预期 | 失败分支 |
|---|---|---|
| 眼镜连热点后，电脑上 `adb connect <眼镜IP>:5555` | 首次眼镜屏幕弹出"允许无线调试？"→ 勾选"始终允许"→ 确定；`connected to ...` | **不弹框**：ROM 裁掉了授权 UI → 这是已知风险。试 `adb shell setprop persist.adb.nonpersist.roots 1` 后重连；仍不行则该眼镜无法走标准 ADB 自动化，回退到手动推流（见第 2 步末尾"回退方案"） |
| `adb shell id` | `uid=2000(shell) ...` | 若返回 `uid=2000` 之外的身份 → 屏幕流抓不到屏，只能验相机流 |
| 眼镜开发者选项里勾选"网络 ADB 授权" | 后续不再弹框 | 不勾选则每次连接都要点，全自动会卡住 |

**iPhone 侧对应验证**：装好 IPA → 打开 App → "iPhone 端连接"区把眼镜 IP 填进去 → 点"① 自动部署采集端" → 看部署日志。预期依次出现：
`CNXN 握手 → AD B 已授权，指纹 ... → 身份 uid=2000 → 两个资源已推送 → 安装 Success → CAMERA 已授予 → 两路已启动`。
若卡在"连接/授权"阶段 → 就是授权框问题，回上面处理。

---

## 第 2 步：单独验两路流（绕开 iPhone，先确认采集端本身正常）

目的：在引入 iPhone 之前，确认眼镜的 9114/9115 真的在推带 pts 的 H264。

**电脑上开探针监听**（两个终端）：

```bash
# 终端 A：屏幕流
python3 tools/stream_probe.py listen --seconds 15 --save-prefix /tmp/glass-screen
# 终端 B：相机流
python3 tools/stream_probe.py listen --seconds 15 --port 9115 --save-prefix /tmp/glass-cam
```

**眼镜端启动采集**（另一个终端，或用第 1 步 iPhone 自动部署的结果）：

```bash
# 屏幕流：shell uid，CLASSPATH 指向 push 上去的 jar
adb shell "CLASSPATH=/data/local/tmp/screen-push.jar app_process / poc.ScreenPush <iPhoneIP> 9114 15 640 400 20 2000000 2 1"
# 相机流：App uid 前台服务
adb shell am start-foreground-service -n com.fusion.capture/.CameraStreamService \
  --es host <iPhoneIP> --ei port 9115 --ei sec 15 --ei width 640 --ei height 480 \
  --ei fps 30 --ei bitrate 2000000 --ei iframe 2 --ei pts 1
```

| 检查 | 预期 | 失败分支 |
|---|---|---|
| 屏幕探针 | 收到帧，SEI pts 解析正常，`streamId=1`，帧率≈20fps | 0 帧 → `SurfaceControl` 虚拟屏镜像被 ROM 拦（定制 ROM 风险）→ 见"回退方案" |
| 相机探针 | 收到帧，`streamId=2`，帧率≈30fps | 0 帧 → `pm grant` 没生效或相机被占用；`adb shell dumpsys media.camera` 看占用 |
| 两路 pts | 探针报告"同源单调时钟，时间差恒定" | 时间差乱跳 → 采集端 `elapsedRealtimeNanos()` 基准被打乱，检查是否重启过眼镜 |
| 保存的 h264 | `/tmp/glass-*.h264` 存在，可 `ffprobe` 出 640x400 / 640x480 | 空文件 → 编码没启动，看 `adb logcat -s ScreenPush CameraStreamService` |

> **回退方案**：若屏幕流 9114 在真眼镜上跑不通（虚拟屏镜像被拦），但相机流 9115 正常——先把相机流接进 iPhone 验单机合成（预览会缺屏幕层，但能验证 ADB+接收+成片链路），屏幕流的 `SurfaceControl` 兼容问题单独记录，回头针对性改 ScreenPush 的反射调用。别因为屏幕流卡住就整条链路不验。

---

## 第 3 步：验 iPhone 全自动部署 + 监听方向

目的：确认 iPhone App 能自动完成"发现→授权→push→启动"，且**监听方向**对得上（v0.3 已修：采集端主动连，iPhone 监听）。

| 操作 | 预期 | 失败分支 |
|---|---|---|
| App "眼镜 IP" 留空，点"① 自动部署采集端" | 自动扫 `5555` → 找到眼镜 → 部署日志走完 6 步 → 显示"两路采集已启动" | 扫不到 → 确认眼镜热点 IP 段、5555 开着；或手动填 IP |
| 部署日志含 `host=<iPhone IP>` | 屏幕流/相机流命令里 host 是 iPhone 地址 | 填成眼镜 IP → 采集端连自己，永远没帧，回第 2 步改 |
| 部署完成后 App 日志出现 `[屏幕/监听] 已连接` / `[相机/监听] 已连接` | 两路主动连进 iPhone 的 NWListener | 无"已连接" → 监听端口被占（重启 App）；或采集端方向还是旧版客户端（确认眼镜 push 的是最新 jar/APK） |

> 手动"从眼镜抓两帧"按钮走的是**旧客户端方向**（iPhone 主动连眼镜），与全自动的监听方向相反。两者刻意并存，别混用：全自动录制只用监听，手动抓帧只用客户端。

---

## 第 4 步：验参数实时预览（WYSIWYG，不依赖录制）

目的：确认滑杆调整实时反映，且合成画面真实。这步不写 mp4，纯看预览。

| 操作 | 预期 | 失败分支 |
|---|---|---|
| 部署+监听成功后，主预览区显示两路真实帧的合成画面 | 暗相机背景 + 中央半透明屏幕层，非手绘示意 | 仍是示意/空白 → 两路没帧，回第 2 步 |
| 拖 10 条滑杆（透明度/占比/偏移/圆角/渐隐/亮度/对比度/裁剪等） | 预览实时变化，无卡顿/无旧帧闪回 | 卡顿 → 正常，异步重算会丢弃过期帧；闪回旧帧是 bug，记下参数组合 |
| 点"保存当前合成帧" | 相册多一张合成图 | 没保存 → 检查相册权限 |

拿这张合成图与交接包的 `三路对照_相机_屏幕_融合.png` 目视对比，确认效果一致。

---

## 第 5 步：验全自动录制 → 成片写相册（核心）

目的：确认 `AVAssetWriter` 逐帧编码、真实 pts 时间轴、成片进相册。

| 操作 | 预期 | 失败分支 |
|---|---|---|
| 点"② 全自动录制"（或主"开始录制"） | 进入录制页，显示"已写入 N 帧"递增 | 不递增 → 两路帧没进队列，回第 3 步 |
| 录 10 秒后点停止 | 显示"正在封装成片并保存相册…" → **等写入回调**才弹完成页（不是一点就弹） | 卡在封装 → AVAssetWriter finalize 卡住，`recordError` 会在日志显示 |
| 打开相册 | 多一段 mp4，1280×720 / 20fps / 约 10 秒 | 没 mp4 → `MovieWriter` 写入失败，看 App 日志 `recordError`；这是沙箱无法验的运行时项，记录具体错误 |
| 播放成片 | 画面与第 4 步预览一致（同源合成） | 画面变样 → **WYSIWYG 被破坏**，拿参数 fingerprint 对照，重点查分辨率/旋转是否一致 |

**逐帧比对基准**：把成片导出到电脑，与 `/workspace/v0.2_离线基准.mp4`（10s/200帧/1280×720/20fps）逐帧比对。参数一致时，两路帧的取帧序号、叠加几何应完全对上——基准清单在 `/workspace/v0.2_基准清单.json`（200 条，每条记录了取了哪路第几帧及 pts）。若参数不同，用 `tools/render_preview.py` 按成片参数重渲一帧对比。

---

## 第 6 步：停止与清理

| 操作 | 预期 |
|---|---|
| 录制页点停止 | App 通过 ADB 下发 `STOP_CAMERA` + `force-stop`，屏幕流靠 TCP 断开（心跳 ≤1 秒感知退出） |
| 电脑探针 / `adb shell ps -A \| grep poc.ScreenPush` | 无残留采集进程 |
| 重开 App 再部署 | 用 Keychain 里已存的密钥直接 AUTH 第 1 轮放行，不再弹授权框 |

---

## 第 7 步：把结果反馈回来（决定下一步）

联调后告诉我这几项，我据此决定修哪里：

1. **授权框**：弹了 / 没弹 / 弹了但点允许后仍连不上？
2. **两路流**：9114 有帧吗？9115 有帧吗？pts 时间差恒定吗？
3. **成片**：mp4 出来了吗？画面和第 4 步预览一致吗？时长/分辨率对吗？
4. **卡在哪一步**：第 1-6 步的具体编号 + App 部署日志最后几行 / `recordError` 内容。

根据结果：
- 全通 → 切 Task #15 清爽界面（收起调试按钮），发 v0.4 正式版。
- 授权框拦路 → 评估是否用企业级签名装 `/system/priv-app` 或改单 APK（MediaProjection）架构。
- 屏幕流 9114 不通 → 针对性改 `ScreenPush.java` 的 `SurfaceControl` 反射。
- 成片异常 → 按 `recordError` 修 `MovieWriter`。
- 预览≠成片 → 查 `FusionParams` fingerprint 两岸是否一致，这是 WYSIWYG 红线。

---

## 附：沙箱已验证 / 真机才验的边界（诚实标注）

| 已验证（沙箱 33/33 契约 + 多轮自测） | 真机才验（本清单覆盖） |
|---|---|
| ADB CNXN/AUTH 两轮 / sync push 字节 / shell 多片输出 | ROM 授权框行为、无线 ADB 稳定性 |
| SEI pts 三实现（Java/Swift/Python）逐字节一致 | 采集端 `elapsedRealtimeNanos` 两进程时钟基准是否真共享 |
| 双路帧数不同（87/97）仍按 pts 锚点对齐、CFR 200 帧 | 真实链路抖动/丢帧下的对齐 |
| Swift 命令构造 ↔ 安卓参数解析逐字段一致 | `pm install` / `MediaCodec` / `Camera2` 运行时 |
| `CaptureOrchestrator` 6 步命令序列、方向（host=iPhone IP） | AVAssetWriter 真机写相册、成片颜色/时长 |

跑清单时任何一步的"预期"没达到，把对应日志发我，不要自己猜着改——很多问题在沙箱侧改一行就能修，但得先看到真机现象。
