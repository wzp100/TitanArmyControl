import Foundation
import TitanArmyCore

/// Language choice for the app UI. The persisted value is the raw string so
/// `@AppStorage` can store it directly.
enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "EN"
        }
    }

    /// Follow the user's macOS preference on first launch.
    static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.lowercased().hasPrefix("zh") ? .chinese : .english
    }

    func pick(_ chinese: String, _ english: String) -> String {
        self == .chinese ? chinese : english
    }
}

/// Small, explicit localization layer for the app.
///
/// The core layer deliberately keeps stable English register identifiers for
/// CLI output and diagnostics. The UI translates those identifiers here so
/// hardware terminology remains consistent in both languages.
struct L10n {
    let language: AppLanguage

    func pick(_ chinese: String, _ english: String) -> String {
        language.pick(chinese, english)
    }

    func registerTitle(_ vcp: UInt8) -> String {
        switch vcp {
        case VCPCode.brightness: return pick("亮度", "Brightness")
        case VCPCode.contrast: return pick("对比度", "Contrast")
        case VCPCode.redGain: return pick("红增益", "Red Gain")
        case VCPCode.greenGain: return pick("绿增益", "Green Gain")
        case VCPCode.blueGain: return pick("蓝增益", "Blue Gain")
        case VCPCode.volume: return pick("音量", "Volume")
        case VCPCode.Vendor.pictureMode: return pick("画面模式", "Picture Mode")
        case VCPCode.Vendor.overdrive: return pick("响应速度", "Overdrive")
        case VCPCode.Vendor.hdrMode: return pick("显示器 HDR", "Monitor HDR")
        case VCPCode.Vendor.screenMode: return pick("屏幕模式", "Screen Mode")
        case VCPCode.Vendor.displayMode: return pick("0x3A 模式", "0x3A Mode")
        default: return String(format: "VCP 0x%02X", vcp)
        }
    }

    func registerNote(_ vcp: UInt8) -> String {
        switch vcp {
        case VCPCode.brightness:
            return pick("硬件背光；HDR 开启时显示器会锁定该寄存器。",
                        "Hardware backlight; locked by the panel while HDR is engaged.")
        case VCPCode.contrast:
            return pick("HDR 关闭时可写；HDR 开启时锁定。",
                        "Writable with HDR off; locked while HDR is engaged.")
        case VCPCode.redGain, VCPCode.greenGain, VCPCode.blueGain:
            return pick("可读取；写入行为尚未确认。",
                        "Reported by the panel; write behaviour not yet confirmed.")
        case VCPCode.volume:
            return pick("直接控制显示器扬声器；HDR 开启时仍可写。",
                        "Controls the monitor speakers; writable even with HDR on.")
        case VCPCode.Vendor.pictureMode:
            return pick("办公/游戏预设使用的画面模式寄存器。",
                        "Picture-mode register used by the Office/Game presets.")
        case VCPCode.Vendor.overdrive:
            return pick("响应速度等级 0–4。",
                        "Overdrive level 0-4.")
        case VCPCode.Vendor.hdrMode:
            return pick("0 关 / 1 自动 / 2 游戏 / 3 电影。目标 0x4A 来自官方命令表和 KDE 抓包。",
                        "0 Off / 1 Auto / 2 Game / 3 Movie. Target 0x4A comes from the official table and a KDE capture.")
        case VCPCode.Vendor.screenMode:
            return pick("双模式/屏幕尺寸选择器，编码尚未确认。",
                        "Dual-mode / screen-size selector. Encoding unconfirmed.")
        case VCPCode.Vendor.displayMode:
            return pick("Windows 界面曾标为 25 英寸宽屏；它不是双模式开关。",
                        "Windows UI called this 25-inch Wide; it is NOT a dual-mode switch.")
        default:
            return ""
        }
    }

    func certainty(_ certainty: TitanArmyProfile.Certainty) -> String {
        switch certainty {
        case .verified: return pick("已验证", "verified")
        case .readOnlyObserved: return pick("只读", "read only")
        case .unverified: return pick("未验证", "unverified")
        case .refuted: return pick("已排除", "refuted")
        }
    }

    func presetTitle(_ preset: TitanArmyProfile.Preset) -> String {
        switch preset.id {
        case "office": return pick("办公", "Office")
        case "game": return pick("游戏", "Game")
        default: return preset.title
        }
    }

    func presetSubtitle(_ preset: TitanArmyProfile.Preset) -> String {
        switch preset.id {
        case "office":
            return pick("最中性的画面模式，关闭响应加速",
                        "Most neutral picture mode, overdrive off")
        case "game":
            return pick("游戏画面模式，最高响应加速",
                        "Game picture mode, maximum overdrive")
        default: return preset.subtitle
        }
    }

    func vendorHDRTitle(_ mode: TitanArmyProfile.VendorHDR) -> String {
        switch mode {
        case .off: return pick("关闭", "Off")
        case .auto: return pick("自动", "Auto")
        case .game: return pick("游戏", "Game")
        case .movie: return pick("电影", "Movie")
        }
    }

    func overdriveTitle(_ level: TitanArmyProfile.Overdrive) -> String {
        switch level {
        case .off: return pick("关闭", "Off")
        case .normal: return pick("正常", "Normal")
        case .fast: return pick("快速", "Fast")
        case .fastest: return pick("最快", "Fastest")
        }
    }

    func localDimmingTitle(_ level: TitanArmyProfile.LocalDimming) -> String {
        switch level {
        case .off: return pick("关闭", "Off")
        case .low: return pick("低", "Low")
        case .smooth: return pick("平滑", "Smooth")
        case .medium: return pick("中", "Medium")
        case .high: return pick("高", "High")
        }
    }

    func windowsSettingTitle(_ setting: TitanArmyProfile.WindowsSetting) -> String {
        switch setting {
        case .sceneMode: return pick("场景模式", "Scene Mode")
        case .colorTemperature: return pick("色温", "Color Temperature")
        case .hdrMode: return pick("显示器 HDR", "Monitor HDR")
        case .localDimming: return pick("分区调光", "Local Dimming")
        case .dynamicOverdrive: return pick("动态 OD", "Dynamic OD")
        case .dyDsULL: return pick("DyDs / ULL", "DyDs / ULL")
        case .nightVision: return pick("夜视", "Night Vision")
        case .sharpness: return pick("锐度", "Sharpness")
        case .lowBlueLight: return pick("低蓝光", "Low Blue Light")
        case .adaptiveSync: return pick("Adaptive-Sync", "Adaptive-Sync")
        case .gamma: return pick("官方 Gamma", "Official Gamma")
        case .gameRush: return "Game Rush"
        case .colorEnhance: return pick("色彩增强", "Color Enhance")
        case .crEnhance: return pick("对比增强", "CR Enhance")
        case .shadowBalance: return pick("暗部平衡", "Shadow Balance")
        case .superResolution: return pick("超级分辨率", "Super Resolution")
        case .haloControl: return pick("光晕控制", "Halo Control")
        case .rgbOutputRange: return pick("输出范围", "Output Range")
        case .gameAssistantRefreshPosition: return pick("刷新率位置", "Refresh Rate Position")
        case .gameAssistantScreenSize: return pick("屏幕尺寸", "Screen Size")
        case .gameAssistantAlignment: return pick("瞄准线", "Alignment Aid")
        case .gameAssistantCrosshair: return pick("准星", "Game Crosshair")
        case .gameAssistantCrosshairShape: return pick("准星形状", "Crosshair Shape")
        case .gameAssistantCrosshairColor: return pick("准星颜色", "Crosshair Color")
        case .gameAssistantStopwatch: return pick("秒表", "Stopwatch")
        case .gameAssistantStopwatchTime: return pick("秒表时长", "Stopwatch Time")
        case .gameAssistantStopwatchPosition: return pick("秒表位置", "Stopwatch Position")
        case .gameAssistantGameTime: return pick("游戏时间", "Game Time")
        case .gameAssistantGameTimeValue: return pick("游戏时间时长", "Game Time Duration")
        case .gameAssistantGameTimePosition: return pick("游戏时间位置", "Game Time Position")
        case .gameAssistantMagnifier: return pick("放大镜", "Magnifier Mode")
        case .gameAssistantMagnifierSize: return pick("放大镜尺寸", "Magnifier Size")
        case .gameAssistantMagnification: return pick("放大倍率", "Magnification")
        case .gameAssistantMagnifierPosition: return pick("放大镜位置", "Magnifier Position")
        case .gameAssistantHawkEye: return pick("鹰眼视觉", "HawkEye Vision")
        case .gameAssistantHawkEyeSize: return pick("鹰眼尺寸", "HawkEye Size")
        case .gameAssistantHawkEyeLevel: return pick("鹰眼等级", "HawkEye Level")
        case .gameAssistantHawkEyePosition: return pick("鹰眼位置", "HawkEye Position")
        case .gameAssistantNightVision: return pick("助手夜视", "Assistant Night Vision")
        case .customSceneSaturation: return pick("自定义饱和度", "Custom Saturation")
        case .customSceneGamma: return pick("自定义 Gamma", "Custom Gamma")
        case .customSceneHue: return pick("自定义色相", "Custom Hue")
        case .customSceneNightVision: return pick("自定义夜视", "Custom Night Vision")
        case .customSceneDynamicOverdrive: return pick("自定义动态 OD", "Custom Dynamic OD")
        case .customSceneCR: return pick("自定义对比增强", "Custom CR Enhance")
        case .customSceneColor: return pick("自定义色彩增强", "Custom Color Enhance")
        }
    }

    func sceneModeTitle(_ mode: TitanArmyProfile.SceneMode) -> String {
        switch mode {
        case .standard: return pick("标准", "Standard")
        case .rtsRpg: return pick("RTS / RPG", "RTS / RPG")
        case .fps: return pick("FPS", "FPS")
        case .moba: return pick("MOBA", "MOBA")
        case .movie: return pick("电影", "Movie")
        case .reading: return pick("阅读", "Reading")
        case .night: return pick("夜间", "Night")
        case .eyeCare: return pick("护眼", "Eye Care")
        case .macView: return pick("Mac 显示", "Mac View")
        case .eBook: return pick("电子书", "E-Book")
        case .sRGB: return pick("sRGB", "sRGB")
        case .adobeRGB: return pick("Adobe RGB", "Adobe RGB")
        case .dciP3: return pick("DCI-P3", "DCI-P3")
        case .dyDsULLFPS: return pick("DyDs / ULL FPS", "DyDs / ULL FPS")
        case .dyDsLocalDimming: return pick("DyDs / 分区调光", "DyDs / Local Dimming")
        case .custom: return pick("自定义", "Custom")
        }
    }

    func sceneModeDetail(_ mode: TitanArmyProfile.SceneMode) -> String {
        switch mode {
        case .standard: return pick("中性日常画面", "Neutral everyday picture")
        case .rtsRpg: return pick("即时战略与角色扮演", "Strategy and role-playing games")
        case .fps: return pick("突出暗部与快速瞄准", "Shadow detail and fast aim")
        case .moba: return pick("技能与地图对比度", "Ability and map clarity")
        case .movie: return pick("电影色调", "Cinematic tone")
        case .reading: return pick("纸质阅读观感", "Paper-like reading")
        case .night: return pick("暗光环境", "Low-light environments")
        case .eyeCare: return pick("长时间用眼", "Long viewing sessions")
        case .macView: return pick("接近 Mac 的色彩", "Mac-like color")
        case .eBook: return pick("文字阅读", "Text reading")
        case .sRGB: return pick("标准色彩空间", "Standard color space")
        case .adobeRGB: return pick("广色域工作", "Wide-gamut work")
        case .dciP3: return pick("DCI-P3 内容", "DCI-P3 content")
        case .dyDsULLFPS: return pick("动态稳定 + 超低延迟 FPS 组合", "Dynamic stability and ULL FPS combination")
        case .dyDsLocalDimming: return pick("动态稳定 + 分区调光组合", "Dynamic stability and local dimming combination")
        case .custom: return pick("进入官方自定义图像模式", "Enter the official custom image mode")
        }
    }

    func colorTemperatureTitle(_ mode: TitanArmyProfile.ColorTemperature) -> String {
        switch mode {
        case .warm: return pick("暖色", "Warm")
        case .natural: return pick("自然", "Natural")
        case .cold: return pick("冷色", "Cold")
        case .user1: return pick("用户 1", "User 1")
        case .user2: return pick("用户 2", "User 2")
        case .user3: return pick("用户 3", "User 3")
        }
    }

    func nightVisionTitle(_ level: TitanArmyProfile.NightVisionLevel) -> String {
        switch level {
        case .off: return pick("关闭", "Close")
        case .level1: return pick("等级 1", "Level 1")
        case .level2: return pick("等级 2", "Level 2")
        case .autoLevel1: return pick("自动 L1", "Auto L1")
        case .autoLevel2: return pick("自动 L2", "Auto L2")
        }
    }

    func officialGammaTitle(_ mode: TitanArmyProfile.OfficialGamma) -> String {
        mode.title
    }

    func rgbOutputRangeTitle(_ range: TitanArmyProfile.RGBOutputRange) -> String {
        switch range {
        case .auto: return pick("自动", "Auto")
        case .limited: return pick("有限", "Limited")
        case .full: return pick("完整", "Full")
        }
    }

    func enhancementTitle(_ enhancement: TitanArmyProfile.Enhancement) -> String {
        windowsSettingTitle(TitanArmyProfile.WindowsSetting(from: enhancement))
    }

    func dynamicOverdriveTitle(_ level: TitanArmyProfile.DynamicOverdriveLevel) -> String {
        switch level {
        case .off: return pick("关闭", "Off")
        case .topspeed: return pick("Topspeed", "Topspeed")
        default: return pick("等级 \(level.rawValue)", "Level \(level.rawValue)")
        }
    }

    func dyDsULLTitle(_ level: TitanArmyProfile.DyDsULLLevel) -> String {
        switch level {
        case .off: return pick("关闭", "Off")
        default: return pick("等级 \(level.rawValue)", "Level \(level.rawValue)")
        }
    }

    func sharpnessTitle(_ level: TitanArmyProfile.SharpnessLevel) -> String {
        switch level {
        case .level0: return pick("关闭", "Off")
        default: return pick("等级 \(level.rawValue)", "Level \(level.rawValue)")
        }
    }

    func lowBlueLightTitle(_ level: TitanArmyProfile.LowBlueLightLevel) -> String {
        switch level {
        case .off: return pick("关闭", "Off")
        default: return pick("等级 \(level.rawValue)", "Level \(level.rawValue)")
        }
    }

    func protocolEvidence(_ setting: TitanArmyProfile.WindowsSetting) -> String {
        if setting == .localDimming || setting == .hdrMode {
            return pick("官方工具动态抓包确认", "Captured from the official utility")
        }
        if setting == .nightVision || setting == .dynamicOverdrive || setting == .sharpness ||
            setting == .adaptiveSync {
            return pick("官方调用点与命令表复核；实机未写入", "Official call site and table; not yet written on this Mac")
        }
        if setting.rawValue.hasPrefix("gameAssistant") {
            return pick("官方电竞助手调用点复核", "Verified from official Game Assistant call sites")
        }
        if setting == .gamma || setting == .gameRush || setting == .colorEnhance ||
            setting == .crEnhance || setting == .shadowBalance || setting == .superResolution ||
            setting == .haloControl || setting == .rgbOutputRange {
            return pick("官方程序调用点复核", "Verified from official call sites")
        }
        if setting.rawValue.hasPrefix("customScene") {
            return pick("官方调用点复核；需先进入自定义场景", "Official call sites; Custom scene must be active")
        }
        return pick("官方程序静态映射；私有目标不可回读", "Static official mapping; private target is not readable")
    }

    func findingTitle(_ finding: HardwareFindings.Finding) -> String {
        switch finding.id {
        case "link": return pick("USB-C DisplayPort Alt Mode 上的 DDC/CI",
                                 "DDC/CI over USB-C DisplayPort Alt Mode")
        case "brightness": return pick("硬件亮度", "Hardware brightness")
        case "hdr-lock": return pick("HDR 会冻结亮度寄存器", "HDR freezes the tone registers")
        case "overdrive": return pick("响应速度 0–4", "Overdrive 0-4")
        case "picture-mode": return pick("画面模式 0 和 3–14", "Picture modes 0 and 3-14")
        case "vendor-hdr": return pick("显示器 HDR 寄存器映射", "Vendor HDR register mapping")
        case "screen-mode": return pick("双模式 / 屏幕模式选择器", "Dual Mode / Screen Mode selector")
        case "adaptive-sync": return "Adaptive-Sync"
        case "official-call-sites": return pick("官方调用点控制", "Official call-site controls")
        default: return finding.title
        }
    }

    func findingDetail(_ finding: HardwareFindings.Finding) -> String {
        switch finding.id {
        case "link":
            return pick("dcpext0 上的 IOAVService 通道工作正常，读写均成功。",
                        "IOAVService channel on dcpext0 works: reads and writes both succeed.")
        case "brightness":
            return pick("关闭 HDR 后，VCP 0x10 可写，并能通过回读确认。",
                        "VCP 0x10 is writable and verified by read-back once HDR is off.")
        case "hdr-lock":
            return pick("HDR 开启时显示器将亮度固定在 100，并忽略 0x10/0x12 写入；关闭 HDR 后可见亮度为 50。",
                        "With HDR on the panel pins brightness to 100 and ignores 0x10/0x12 writes; turning HDR off revealed 50.")
        case "overdrive":
            return pick("VCP 0xE1 接受从关闭到 4 的所有等级，并能正确回读。",
                        "VCP 0xE1 accepts every level from Off to 4 and reads back correctly.")
        case "picture-mode":
            return pick("VCP 0xE0 拒绝 1 和 2；最大 14，其他值均可接受。",
                        "VCP 0xE0 rejects 1 and 2; all other values up to 14 are accepted.")
        case "vendor-hdr":
            return pick("旧探测码 0xE2 在此连接上只报告 0–1 范围；官方 HDR 命令目标是 0x4A，值 0/1/2/3 尚未实机写入。",
                        "Legacy probe 0xE2 reports a 0-1 range here. The official HDR target is 0x4A; values 0/1/2/3 are not yet written on this Mac.")
        case "screen-mode":
            return pick("未能确认任何可切换双模式的 VCP。0x3A 完全不可读，因此无法复现 Windows 的“25 英寸宽屏”标签。",
                        "No VCP could be confirmed to switch dual mode. VCP 0x3A is not readable at all, so the Windows '25-inch Wide' label cannot be reproduced.")
        case "adaptive-sync":
            return pick("官方工具另有 0x99/0xE4 的私有开关；链路层仍会协商 VRR。当前通道不能回读该状态。",
                        "The official utility has a private 0x99/0xE4 toggle in addition to link-level VRR. Its state cannot be read here.")
        case "official-call-sites":
            return pick("Gamma、Game Rush、输出范围和五个画面增强滑条来自官方调用点。目标映射可信，但画面效果尚未在本机验证。",
                        "Gamma, Game Rush, output range and five enhancement sliders come from official call sites. Targets are authoritative, but effects are not verified on this Mac.")
        default:
            return finding.detail
        }
    }

    /// Translate the errors that can reach the UI without leaking English
    /// implementation details into the Chinese experience.
    func error(_ error: Error) -> String {
        if let failure = error as? MonitorController.Failure {
            switch failure {
            case .noDDCChannel:
                return pick("未找到 DDC/CI 通道。请使用 DisplayPort 或 USB-C 连接显示器。",
                            "No DDC/CI channel. Reconnect the monitor over DisplayPort or USB-C.")
            case .toneLockedByHDR:
                return pick("HDR 已开启，显示器会锁定亮度和对比度。请先关闭 HDR。",
                            "HDR is on. Brightness and contrast are locked by the monitor while HDR is active.")
            case let .unsupportedRegister(vcp):
                return pick(String(format: "显示器不支持寄存器 0x%02X。", vcp),
                            String(format: "The display does not expose VCP 0x%02X.", vcp))
            case let .unknownPreset(id):
                return pick("未知预设“\(id)”。", "Unknown preset '\(id)'.")
            case let .valueOutOfRange(setting):
                return pick("数值超出“\(windowsSettingTitle(setting))”的官方范围。", "The value is outside the official range for '\(windowsSettingTitle(setting))'.")
            }
        }
        if let ddc = error as? DDCError {
            switch ddc {
            case let .noValidReply(vcp):
                return pick(String(format: "寄存器 0x%02X 未返回有效数据。", vcp),
                            String(format: "No valid DDC reply for VCP 0x%02X", vcp))
            case let .unsupported(vcp):
                return pick(String(format: "显示器不支持寄存器 0x%02X。", vcp),
                            String(format: "VCP 0x%02X is not supported by this display", vcp))
            case let .transportFailure(vcp, status):
                return pick(String(format: "寄存器 0x%02X 的 I2C 传输失败（0x%08X）。", vcp, UInt32(bitPattern: status)),
                            String(format: "I2C write failed for VCP 0x%02X (0x%08X)", vcp, UInt32(bitPattern: status)))
            case let .notApplied(vcp, requested, observed):
                return pick(String(format: "寄存器 0x%02X 写入被忽略：请求 %d，显示器仍为 %d。", vcp, requested, observed),
                            String(format: "VCP 0x%02X write ignored: requested %d, display kept %d", vcp, requested, observed))
            case let .outOfRange(vcp, value, maximum):
                return pick(String(format: "寄存器 0x%02X 的值 %d 超过上限 %d。", vcp, value, maximum),
                            String(format: "VCP 0x%02X value %d exceeds maximum %d", vcp, value, maximum))
            }
        }
        return pick("操作失败：\(error.localizedDescription)", "Operation failed: \(error.localizedDescription)")
    }
}
