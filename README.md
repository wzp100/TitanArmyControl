# TitanArmyControl

面向 Titan Army P275MV PLUS (EDID `LHC 0x907D`) 的跨平台显示器控制应用。
业务规则、设备能力和寄存器定义保持跨平台一致，界面与 DDC/CI 传输层按操作系统
分别实现。

## 平台状态

- macOS 27+：已实现，使用 SwiftUI 与 Apple Silicon `IOAVService`。
- Windows：开发中，计划使用 Microsoft.UI.Reactor 与 `dxva2.dll` DDC/CI API。

界面支持简体中文与英文，首次启动跟随系统语言，可在应用内即时切换。

## 界面

按照 `DESIGN.md` 使用原生 `NavigationSplitView` 侧边栏与系统 Liquid Glass 工具栏，
跟随 macOS 浅色、深色与辅助功能设置。日常操作位于“显示与声音”，预设和响应速度
位于“画面与响应”，硬件诊断与寄存器参考收纳在“设备信息”。刷新快捷键为 `⌘R`。

最低要求为 macOS 27，使用 Xcode 27 SDK 构建，不包含旧版系统兼容分支。

## 启动

```sh
cd /Users/jackcuda/Desktop/Code/TitanArmyControl
open build/TitanArmy.app
```

应用使用临时签名，仅适合在本机运行。首次启动若被系统拦截，请在
“系统设置 → 隐私与安全性”中允许打开。

命令行工具位于：

```text
build/TitanArmy.app/Contents/MacOS/titanarmyctl
```

## 命令行

```sh
CLI=build/TitanArmy.app/Contents/MacOS/titanarmyctl

"$CLI" list                     # 列出显示器
"$CLI" status                   # 当前状态
"$CLI" probe                    # 读取已知寄存器
"$CLI" brightness 30            # HDR 关闭时设置亮度（0-100）
"$CLI" contrast 50              # HDR 关闭时设置对比度（0-100）
"$CLI" volume 65                # 设置显示器扬声器音量
"$CLI" scene standard           # 标准场景
"$CLI" scene fps                # FPS 场景（完整场景见界面）
"$CLI" colortemp cold           # 冷色色温
"$CLI" nightvision 3            # 夜视等级
"$CLI" dynamicod 4              # 动态 OD / Topspeed
"$CLI" dydsull off              # DyDs / ULL
"$CLI" sharpness 2              # 锐度等级
"$CLI" lowbluelight 1           # 低蓝光等级
"$CLI" adaptivesync on          # Adaptive-Sync
"$CLI" hdr off                  # 关闭 macOS HDR
"$CLI" hdr on                   # 打开 macOS HDR
"$CLI" od 3                     # 设置 Overdrive（0–4）
"$CLI" vendorhdr 1              # 写显示器 HDR 寄存器（实验性）
"$CLI" localdimming medium      # 官方协议分区调光
"$CLI" monitorhdr movie         # 官方协议显示器 HDR 模式
"$CLI" assistant screen 27      # 屏幕尺寸
"$CLI" assistant crosshair on   # 准星开关；1-6 直接开并选形状
"$CLI" assistant crosshaircolor auto
"$CLI" assistant stopwatch 30   # 秒表时长；on/off 是开关
"$CLI" assistant stopwatchpos 1
"$CLI" assistant gametime 45    # 游戏时间时长；on/off 是开关
"$CLI" assistant gametimepos 2
"$CLI" assistant magnifier large
"$CLI" assistant magnification 4
"$CLI" assistant magnifierpos 4
"$CLI" assistant alignment on
"$CLI" assistant hawkeye on     # 也支持 0-3 等级 / small|medium|large / 0-3 位置
"$CLI" assistant hawkeyelevel 3
"$CLI" assistant hawkeyesize medium
"$CLI" assistant hawkeyepos 3
"$CLI" assistant hawkeyenightvision 2
```

## 已验证功能

- 识别 P275MV PLUS 与 USB-C DisplayPort Alt Mode 上的 DDC/CI 通道。
- 读取亮度、对比度、音量和厂商寄存器。
- HDR 关闭时写入硬件亮度和对比度，并通过回读确认结果。
- 在启用系统音量组件后，显示器音量由 Core Audio 软件混音控制，键盘与控制中心共用系统音量。
- 应用 Office 与 Game 预设（画面模式分别为 0、3，Overdrive 为 0、3）。
- 切换 macOS HDR。切换后等待链路重新训练，期间不发送 DDC 请求。
- 对读取重试、校验和验证、畸形回复过滤，以及写入后的回读验证。
- 52 个 Swift 测试和 70 项 HAL 驱动检查全部通过；音量、静音、媒体键、应用关闭后播放、
  输出恢复和持久化已在本机实机验证。

应用图标母版为 `Assets/AppIcon-1024.png`，打包资源为
`Assets/AppIcon.icns`。

## 关键硬件发现

**HDR 会锁定亮度与对比度。** HDR 开启时，显示器将亮度寄存器固定在 100，
并静默忽略对 VCP `0x10` / `0x12` 的写入；I2C 仍会返回成功，因此不能只凭
传输成功判断设置已生效。应用会直接识别该状态并提示先关闭 HDR，不发送无效
写入。

HDR 切换还会使 DisplayPort 链路重新训练，DDC 通常中断约 6–12 秒。应用在
切换后等待 6 秒再读取状态。

其他实测结果：

- 画面模式 `0xE0` 最大值为 14；固件拒绝值 1 和 2，接受 0 与 3–14。
- Overdrive `0xE1` 接受 0–4。
- 旧探测码 `0xE2` 在当前连接上只报告 0–1 范围；官方 HDR 命令目标实际是 `0x4A`。
- `0x3A` 无法读取，`0xF3` 返回值不合理；尚未确认双模式切换寄存器。
- 标准寄存器区未发现 Adaptive-Sync/VRR 寄存器；官方开关使用 `0x99 + 0xE4`。

## 尚未验证

- Windows 资料中的“25-inch Wide”/双模式寄存器映射。
- 官方显示器 HDR 值 2、3 的画面效果；目标 `0x4A` 已复核但未实机写入。
- RGB Gain 的写入行为（目前仅读取）。
- 预设切换后的实际画面观感；当前验证依据是寄存器回读。
- Adaptive-Sync 的实机写入效果；官方目标 `0xE4` 已复核但未写入。

## 官方工具补齐控制

场景模式、Custom 场景、色温、显示器 HDR、分区调光、动态 OD、DyDs/ULL、夜视、锐度、低蓝光、
官方 Gamma、Game Rush、输出范围、画面增强滑条和电竞助手使用官方 Windows 工具的
两段式 DDC/CI 协议：先写命令选择器 `0x99`，再把相同值写入目标寄存器。关键映射
包括：场景 `0x22`（15 档 + Custom），色温 `0x14`，HDR `0x4A`（关闭/自动/游戏/电影），
分区调光 `0x47`，动态 OD `0x49`，DyDs/ULL `0x48`，夜视 `0x66`（关闭、L1、L2、
自动 L1、自动 L2），锐度 `0x87`，低蓝光 `0xD8`，Adaptive-Sync `0xE4`，官方
Gamma `0x26`，Game Rush `0x43`，RGB 输出范围 `0x55`，色彩增强 `0x40`（0–10），
CR 增强 `0x41`（0–5），暗部平衡 `0x42`（0–100），超级分辨率 `0x44`（0–5），
光晕控制 `0x9D`（0–100）。Custom 场景会先写 `0x20`，再写入饱和度 `0x59`、
Gamma `0x5A`、色相 `0x5B`、自定义夜视 `0x56` 等图像子项。电竞助手另覆盖屏幕尺寸、准星、秒表、游戏时间、放大
镜、瞄准线、鹰眼，以及鹰眼尺寸/位置/等级/夜视。应用只允许这些类型化取值，不
提供任意私有寄存器写入。

场景协议有一个容易误判的细节：目标码 `0x22` 在功能上像私有码，但官方协议表
和写路径都要求它只跟在 `0x99` 选择器后面发送。场景写入前没有通用回读确认；
选择后请用画面或显示器 OSD 验证。

业务逻辑也按官方工具补齐：开关会在应用内记录最近请求，重复选择相同状态时不
再重发 DDC 命令；显示重连或手动重置后可重新写入。前四个电竞助手覆盖层互斥，
启用一个时会像官方一样向另外三个发送清除值；这些清除写不经过相同状态去重。
官方场景页的 Default/Custom
本质是向场景目标写奇数/偶数值；Custom 是额外场景档位。Custom 的 RGB/Hue/
Saturation 子项已按官方调用点补齐，但需先进入 Custom，画面效果尚未实机验证。

其中分区调光和显示器 HDR 另有官方工具动态抓包证实；其余映射来自官方二进制
协议表复核。当前实机只读探测确认这些私有目标在 macOS 通道上不可回读，所以
应用不会伪造“当前场景/等级”，更改后请以画面或 OSD 为准。

这两项私有状态通常无法可靠回读，所以界面不会伪造当前值；更改后请通过画面
或 OSD 确认。切换显示器 HDR 模式会短暂黑屏或重训链路，操作后会等待约 1.5 秒。

## 开发与测试

```sh
# 需要 Xcode 工具链；Command Line Tools 缺少 SwiftUI 宏插件和 XCTest
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test
./scripts/build-app.sh
```

仅在开发时使用的硬件探测器：

```sh
swift run -q ReadProbe
swift run -q ReadProbe --restore
```

`--restore` 会将显示器恢复到 HDR 开启、亮度 100、对比度 50、音量 100、
画面模式 0、Overdrive 0、显示器 HDR 0、输入 15。恢复后仍需执行
`titanarmyctl hdr on` 以重新开启 macOS HDR。

## 界面截图检查

在 Mac 解锁状态下捕获实际运行窗口（包含系统工具栏与液态玻璃），仅读取显示器状态，不修改硬件设置：

```sh
open -n -W build/TitanArmy.app --args --render-snapshot /tmp/titanarmy-light.png --snapshot-language zh-Hans
open -n -W build/TitanArmy.app --args --render-snapshot /tmp/titanarmy-dark.png --snapshot-appearance dark
open -n -W build/TitanArmy.app --args --render-snapshot /tmp/titanarmy-small.png --snapshot-width 760 --snapshot-height 620
open -n -W build/TitanArmy.app --args --render-snapshot /tmp/titanarmy-picture.png --snapshot-page picture
open -n -W build/TitanArmy.app --args --render-snapshot /tmp/titanarmy-empty.png --snapshot-empty
```

截图使用 ScreenCaptureKit 的当前进程窗口接口，不申请屏幕录制权限。
`--snapshot-language` 仅影响本次截图，不更改用户保存的语言偏好。

## 系统音量与显示器音频

“显示与声音 → 声音 → 启用…”会通过 macOS 的管理员认证安装 `TitanArmyAudio.driver`，
并将默认声音与系统提示音输出切到 `Titan Army Audio`。这个输出将 Core Audio 混音后的
立体声 PCM 转发到 P275MV PLUS，并在软件中统一处理音量与静音。显示器自身音量保持
原值；不会因为按音量键而写入 DDC 音量寄存器。声音区域另有“显示器”滑条，直接写入
显示器扬声器的硬件音量（VCP `0x62`，一次绝对写入并回读确认）。

安装后，控制中心、键盘音量/静音键与应用滑块共用标准 Core Audio 音量状态，音量和
静音会保留到重启后。播放由系统音频组件负责，退出控制面板不会停止声音。切到耳机
或其他输出时，应用不会抢回默认输出。要恢复原设备，在声音区域的选项菜单选择
“恢复之前的输出”；同一菜单提供“卸载音频组件…”。卸载会先恢复输出，再移除组件。

组件安装在 `/Library/Audio/Plug-Ins/HAL/TitanArmyAudio.driver`，运行在用户态。
不需要内核扩展、DriverKit 授权、关闭 SIP 或修改系统安全策略。安装/卸载需要重载
Core Audio，正在播放的声音会短暂停顿。现有其他音频组件保持不变。

```sh
build/TitanArmy.app/Contents/MacOS/titanarmyctl audio status
build/TitanArmy.app/Contents/MacOS/titanarmyctl audio enable
build/TitanArmy.app/Contents/MacOS/titanarmyctl audio volume 40
build/TitanArmy.app/Contents/MacOS/titanarmyctl audio mute on
build/TitanArmy.app/Contents/MacOS/titanarmyctl audio mute off
build/TitanArmy.app/Contents/MacOS/titanarmyctl audio disable
./scripts/test-audio-driver.sh
```

驱动基于 [Proxy Audio Device](https://github.com/briankendall/proxy-audio-device) 的固定版本，
采用 Unlicense；来源、版本与所有本地适配见 `Vendor/ProxyAudioDevice/UPSTREAM.md` 和
`AudioDriver/prepare.py`。Apple PublicUtility 文件保留原样本代码许可。
驱动测试开启 AddressSanitizer 与 UndefinedBehaviorSanitizer，覆盖 PCM 软件增益、
静音、声道布局、不同缓冲区、音量持久化与类型化 HAL 属性。
