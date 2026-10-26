import Foundation

/// Everything this project knows about the P275MV PLUS firmware, including what
/// it explicitly does *not* know.
///
/// Verification status is part of the data model on purpose. The retired Windows
/// UI shipped labels that did not match the registers, so nothing is presented
/// as "verified" unless it was read back from the panel on this Mac.
public enum TitanArmyProfile {
    public static let modelName = "P275MV PLUS"

    /// Capability level of a register, surfaced verbatim in the UI.
    public enum Certainty: String, Sendable {
        /// Read and written on this Mac, value confirmed by read-back.
        case verified
        /// Value readable, semantics inferred from a reference protocol.
        case readOnlyObserved
        /// Address known from the Windows reference; not yet exercised here.
        case unverified
        /// Explicitly refuted by evidence; never offered to the user.
        case refuted
    }

    public struct Register: Sendable {
        public let vcp: UInt8
        public let title: String
        public let certainty: Certainty
        public let note: String
    }

    public static let registers: [Register] = [
        Register(vcp: VCPCode.brightness, title: "Brightness", certainty: .verified,
                 note: "Hardware backlight; ignored by the panel while HDR is engaged."),
        Register(vcp: VCPCode.contrast, title: "Contrast", certainty: .verified,
                 note: "Writable with HDR off; locked while HDR is engaged."),
        Register(vcp: VCPCode.redGain, title: "Red Gain", certainty: .readOnlyObserved,
                 note: "Reported by the panel; write behaviour not yet confirmed."),
        Register(vcp: VCPCode.greenGain, title: "Green Gain", certainty: .readOnlyObserved,
                 note: "Reported by the panel; write behaviour not yet confirmed."),
        Register(vcp: VCPCode.blueGain, title: "Blue Gain", certainty: .readOnlyObserved,
                 note: "Reported by the panel; write behaviour not yet confirmed."),
        Register(vcp: VCPCode.volume, title: "Volume", certainty: .verified,
                 note: "Writable even with HDR on; used to prove the transport works."),
        Register(vcp: VCPCode.Vendor.pictureMode, title: "Picture Mode", certainty: .readOnlyObserved,
                 note: "Read-only compatibility register. Use the official scene protocol instead."),
        Register(vcp: VCPCode.Vendor.overdrive, title: "Overdrive", certainty: .verified,
                 note: "Directly writable and read back; do not confuse with the official Dynamic OD protocol."),
        Register(vcp: VCPCode.Vendor.legacyHDRProbe, title: "Legacy HDR Probe", certainty: .readOnlyObserved,
                 note: "Readable range is 0-1; not the official HDR control."),
        Register(vcp: VCPCode.Vendor.sceneMode, title: "Scene Mode", certainty: .unverified,
                 note: "Official target behind selector 0x99; read is not exposed by this macOS connection."),
        Register(vcp: VCPCode.Vendor.colorTemperature, title: "Color Temperature", certainty: .unverified,
                 note: "Official target behind selector 0x99; read is not exposed by this macOS connection."),
        Register(vcp: VCPCode.Vendor.adaptiveSync, title: "Adaptive-Sync", certainty: .unverified,
                 note: "Official target behind selector 0x99."),
        Register(vcp: VCPCode.Vendor.lowBlueLight, title: "Low Blue Light", certainty: .unverified,
                 note: "Official target behind selector 0x99."),
        Register(vcp: VCPCode.Vendor.nightVision, title: "Night Vision", certainty: .unverified,
                 note: "Official target behind selector 0x99."),
        Register(vcp: VCPCode.Vendor.dynamicOverdrive, title: "Dynamic OD", certainty: .unverified,
                 note: "Official target behind selector 0x99."),
        Register(vcp: VCPCode.Vendor.sharpness, title: "Sharpness", certainty: .unverified,
                 note: "Official target behind selector 0x99."),
        Register(vcp: VCPCode.Vendor.dyDsULL, title: "DyDs / ULL", certainty: .unverified,
                 note: "Official target behind selector 0x99."),
        Register(vcp: VCPCode.Vendor.gamma, title: "Official Gamma", certainty: .unverified,
                 note: "Official call-site mapping behind selector 0x99."),
        Register(vcp: VCPCode.Vendor.gameRush, title: "Game Rush", certainty: .unverified,
                 note: "Official toggle behind selector 0x99; identical requests are skipped."),
        Register(vcp: VCPCode.Vendor.colorEnhance, title: "Color Enhance", certainty: .unverified,
                 note: "Official slider, 0-10, behind selector 0x99."),
        Register(vcp: VCPCode.Vendor.crEnhance, title: "CR Enhance", certainty: .unverified,
                 note: "Official slider, 0-5, behind selector 0x99."),
        Register(vcp: VCPCode.Vendor.shadowBalance, title: "Shadow Balance", certainty: .unverified,
                 note: "Official slider, 0-100, behind selector 0x99."),
        Register(vcp: VCPCode.Vendor.superResolution, title: "Super Resolution", certainty: .unverified,
                 note: "Official slider, 0-5, behind selector 0x99."),
        Register(vcp: VCPCode.Vendor.haloControl, title: "Halo Control", certainty: .unverified,
                 note: "Official slider, 0-100, behind selector 0x99."),
        Register(vcp: VCPCode.Vendor.rgbOutputRange, title: "RGB Output Range", certainty: .unverified,
                 note: "Official selector: Auto, Limited or Full."),
        Register(vcp: VCPCode.Vendor.screenMode, title: "Screen Mode", certainty: .unverified,
                 note: "Dual-mode / screen-size selector. Encoding unconfirmed."),
        Register(vcp: VCPCode.Vendor.displayMode, title: "0x3A Mode", certainty: .refuted,
                 note: "Windows UI called this 25-inch Wide; it is NOT the dual-mode switch."),
    ]

    public static func register(_ vcp: UInt8) -> Register? {
        registers.first { $0.vcp == vcp }
    }

    // MARK: - Presets

    /// Deprecated direct-register convenience presets. Official scene presets
    /// are represented by `SceneMode` and use selector + target writes.
    public struct Preset: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let subtitle: String
        public let values: [UInt8: UInt16]
    }

    public static let presets: [Preset] = [
        Preset(
            id: "office",
            title: "Office",
            subtitle: "Most neutral picture mode, overdrive off",
            values: [VCPCode.Vendor.pictureMode: PictureMode.standard, VCPCode.Vendor.overdrive: 0]
        ),
        Preset(
            id: "game",
            title: "Game",
            subtitle: "Game picture mode, maximum overdrive",
            values: [VCPCode.Vendor.pictureMode: PictureMode.game, VCPCode.Vendor.overdrive: 3]
        ),
    ]

    public static func preset(id: String) -> Preset? {
        presets.first { $0.id == id }
    }

    /// Read-only compatibility observations; not a control protocol.
    public enum PictureMode {
        public static let standard: UInt16 = 0
        public static let game: UInt16 = 3
        /// Values 1 and 2 are reserved/rejected by this firmware.
        public static let reserved: Set<UInt16> = [1, 2]
    }

    // MARK: - Windows control protocol

    /// Settings from the retired Windows utility that use a two-command
    /// sequence: a selector value is sent to `0x99`, then repeated to the
    /// setting-specific code. Targets come from the utility's command table;
    /// local DDC/CI and Linux captures confirm Local Dimming and HDR.
    public enum WindowsSetting: String, CaseIterable, Sendable {
        case sceneMode = "scene"
        case colorTemperature = "colorTemperature"
        case hdrMode = "hdr"
        case localDimming = "localDimming"
        case dynamicOverdrive = "dynamicOverdrive"
        case dyDsULL = "dyDsULL"
        case nightVision = "nightVision"
        case sharpness = "sharpness"
        case lowBlueLight = "lowBlueLight"
        case adaptiveSync = "adaptiveSync"
        case gamma = "gamma"
        case gameRush = "gameRush"
        case colorEnhance = "colorEnhance"
        case crEnhance = "crEnhance"
        case shadowBalance = "shadowBalance"
        case superResolution = "superResolution"
        case haloControl = "haloControl"
        case rgbOutputRange = "rgbOutputRange"
        case gameAssistantRefreshPosition = "gameAssistantRefreshPosition"
        case gameAssistantScreenSize = "gameAssistantScreenSize"
        case gameAssistantAlignment = "gameAssistantAlignment"
        case gameAssistantCrosshair = "gameAssistantCrosshair"
        case gameAssistantCrosshairShape = "gameAssistantCrosshairShape"
        case gameAssistantCrosshairColor = "gameAssistantCrosshairColor"
        case gameAssistantStopwatch = "gameAssistantStopwatch"
        case gameAssistantStopwatchTime = "gameAssistantStopwatchTime"
        case gameAssistantStopwatchPosition = "gameAssistantStopwatchPosition"
        case gameAssistantGameTime = "gameAssistantGameTime"
        case gameAssistantGameTimeValue = "gameAssistantGameTimeValue"
        case gameAssistantGameTimePosition = "gameAssistantGameTimePosition"
        case gameAssistantMagnifier = "gameAssistantMagnifier"
        case gameAssistantMagnifierSize = "gameAssistantMagnifierSize"
        case gameAssistantMagnification = "gameAssistantMagnification"
        case gameAssistantMagnifierPosition = "gameAssistantMagnifierPosition"
        case gameAssistantHawkEye = "gameAssistantHawkEye"
        case gameAssistantHawkEyeSize = "gameAssistantHawkEyeSize"
        case gameAssistantHawkEyeLevel = "gameAssistantHawkEyeLevel"
        case gameAssistantHawkEyePosition = "gameAssistantHawkEyePosition"
        case gameAssistantNightVision = "gameAssistantNightVision"
        case customSceneSaturation = "customSceneSaturation"
        case customSceneGamma = "customSceneGamma"
        case customSceneHue = "customSceneHue"
        case customSceneNightVision = "customSceneNightVision"
        case customSceneDynamicOverdrive = "customSceneDynamicOverdrive"
        case customSceneCR = "customSceneCR"
        case customSceneColor = "customSceneColor"

        public var selector: UInt8 { VCPCode.Vendor.selector }
        public var register: UInt8 {
            switch self {
            case .sceneMode: return VCPCode.Vendor.sceneMode
            case .colorTemperature: return VCPCode.Vendor.colorTemperature
            case .hdrMode: return VCPCode.Vendor.hdrMode
            case .localDimming: return VCPCode.Vendor.localDimming
            case .dynamicOverdrive: return VCPCode.Vendor.dynamicOverdrive
            case .dyDsULL: return VCPCode.Vendor.dyDsULL
            case .nightVision: return VCPCode.Vendor.nightVision
            case .sharpness: return VCPCode.Vendor.sharpness
            case .lowBlueLight: return VCPCode.Vendor.lowBlueLight
            case .adaptiveSync: return VCPCode.Vendor.adaptiveSync
            case .gamma: return VCPCode.Vendor.gamma
            case .gameRush: return VCPCode.Vendor.gameRush
            case .colorEnhance: return VCPCode.Vendor.colorEnhance
            case .crEnhance: return VCPCode.Vendor.crEnhance
            case .shadowBalance: return VCPCode.Vendor.shadowBalance
            case .superResolution: return VCPCode.Vendor.superResolution
            case .haloControl: return VCPCode.Vendor.haloControl
            case .rgbOutputRange: return VCPCode.Vendor.rgbOutputRange
            case .gameAssistantRefreshPosition: return VCPCode.Vendor.gameAssistantRefreshPosition
            case .gameAssistantScreenSize: return VCPCode.Vendor.gameAssistantScreenSize
            case .gameAssistantAlignment: return VCPCode.Vendor.gameAssistantAlignmentEnable
            case .gameAssistantCrosshair: return VCPCode.Vendor.gameAssistantCrosshairEnable
            case .gameAssistantCrosshairShape: return VCPCode.Vendor.gameAssistantCrosshairShape
            case .gameAssistantCrosshairColor: return VCPCode.Vendor.gameAssistantCrosshairColor
            case .gameAssistantStopwatch: return VCPCode.Vendor.gameAssistantStopwatchEnable
            case .gameAssistantStopwatchTime: return VCPCode.Vendor.gameAssistantStopwatchTime
            case .gameAssistantStopwatchPosition: return VCPCode.Vendor.gameAssistantStopwatchPosition
            case .gameAssistantGameTime: return VCPCode.Vendor.gameAssistantGameTimeEnable
            case .gameAssistantGameTimeValue: return VCPCode.Vendor.gameAssistantGameTime
            case .gameAssistantGameTimePosition: return VCPCode.Vendor.gameAssistantGameTimePosition
            case .gameAssistantMagnifier: return VCPCode.Vendor.gameAssistantMagnifierEnable
            case .gameAssistantMagnifierSize: return VCPCode.Vendor.gameAssistantMagnifierSize
            case .gameAssistantMagnification: return VCPCode.Vendor.gameAssistantMagnification
            case .gameAssistantMagnifierPosition: return VCPCode.Vendor.gameAssistantMagnifierPosition
            case .gameAssistantHawkEye: return VCPCode.Vendor.gameAssistantHawkEyeEnable
            case .gameAssistantHawkEyeSize: return VCPCode.Vendor.gameAssistantHawkEyeSize
            case .gameAssistantHawkEyeLevel: return VCPCode.Vendor.gameAssistantHawkEyeLevel
            case .gameAssistantHawkEyePosition: return VCPCode.Vendor.gameAssistantHawkEyePosition
            case .gameAssistantNightVision: return VCPCode.Vendor.gameAssistantNightVisionEnable
            case .customSceneSaturation: return VCPCode.Vendor.CustomScene.saturation
            case .customSceneGamma: return VCPCode.Vendor.CustomScene.gamma
            case .customSceneHue: return VCPCode.Vendor.CustomScene.hue
            case .customSceneNightVision: return VCPCode.Vendor.CustomScene.nightVision
            case .customSceneDynamicOverdrive: return VCPCode.Vendor.CustomScene.dynamicOverdrive
            case .customSceneCR: return VCPCode.Vendor.CustomScene.crEnhance
            case .customSceneColor: return VCPCode.Vendor.CustomScene.colorEnhance
            }
        }

        /// Official slider ranges. Enumerated settings are constrained by
        /// their typed value enums instead, so they keep the full byte range.
        public var allowedRange: ClosedRange<Int> {
            switch self {
            case .crEnhance, .superResolution, .customSceneGamma: return 0...5
            case .customSceneNightVision: return 0...4
            case .colorEnhance, .customSceneDynamicOverdrive, .customSceneCR, .customSceneColor: return 0...10
            case .shadowBalance, .haloControl, .customSceneSaturation, .customSceneHue: return 0...100
            default: return 0...255
            }
        }

        public init(from enhancement: Enhancement) {
            self = switch enhancement {
            case .colorEnhance: .colorEnhance
            case .crEnhance: .crEnhance
            case .shadowBalance: .shadowBalance
            case .superResolution: .superResolution
            case .haloControl: .haloControl
            }
        }

        /// A blank/renegotiation can silently discard commands around monitor
        /// HDR changes; this matches the conservative delay used by captured
        /// Linux implementations.
        public var settleSeconds: Double { self == .hdrMode ? 1.5 : 0.2 }
    }

    public enum Enhancement: String, CaseIterable, Sendable {
        case colorEnhance
        case crEnhance
        case shadowBalance
        case superResolution
        case haloControl

        public var windowsSetting: WindowsSetting { WindowsSetting(from: self) }
        public var allowedRange: ClosedRange<Int> { windowsSetting.allowedRange }

        public var title: String {
            switch self {
            case .colorEnhance: return "Color Enhance"
            case .crEnhance: return "CR Enhance"
            case .shadowBalance: return "Shadow Balance"
            case .superResolution: return "Super Resolution"
            case .haloControl: return "Halo Control"
            }
        }
    }

    public enum LocalDimming: UInt16, CaseIterable, Sendable {
        case off = 2
        case low = 3
        case smooth = 4
        case medium = 5
        case high = 6

        public var title: String {
            switch self {
            case .off: return "Off"
            case .low: return "Low"
            case .smooth: return "Smooth"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
    }

    /// Input values observed on this exact panel.
    ///
    /// The current USB-C connection reports 15. The Windows utility's input
    /// page does not expose a numeric table in its translations, so no other
    /// value is labelled or offered.
    public enum InputSource: UInt16, CaseIterable, Sendable {
        case usbC = 15
    }

    // MARK: - Enumerations

    /// Vendor HDR values from the reference protocol.
    ///
    /// These labels are the reference's, not the retired Windows UI's, which
    /// wrongly presented value 3 as "Auto".
    public enum VendorHDR: UInt16, CaseIterable, Sendable {
        case off = 0
        case auto = 1
        case game = 2
        case movie = 3

        public var title: String {
            switch self {
            case .off: return "Off"
            case .auto: return "Auto"
            case .game: return "Game"
            case .movie: return "Movie"
            }
        }
    }

    /// Overdrive levels, valid only when the panel reports maximum 3+.
    public enum Overdrive: UInt16, CaseIterable, Sendable {
        case off = 0
        case normal = 1
        case fast = 2
        case fastest = 3

        public var title: String {
            switch self {
            case .off: return "Off"
            case .normal: return "Normal"
            case .fast: return "Fast"
            case .fastest: return "Fastest"
            }
        }
    }

    // MARK: - Official scene modes

    /// The complete scene list used by the retired Windows utility.
    ///
    /// Values are the official internal command values. Human-readable names
    /// come from the utility's UI/resource strings and translations; the DyDs
    /// entries are exact internal identifiers because they combine two feature
    /// names in a way not exposed as a friendly translated label.
    public enum SceneMode: UInt16, CaseIterable, Sendable {
        case standard = 0x02
        case rtsRpg = 0x04
        case fps = 0x06
        case moba = 0x08
        case movie = 0x0A
        case reading = 0x0C
        case night = 0x0E
        case eyeCare = 0x10
        case macView = 0x12
        case eBook = 0x14
        case sRGB = 0x16
        case adobeRGB = 0x18
        case dciP3 = 0x1A
        case dyDsULLFPS = 0x1C
        case dyDsLocalDimming = 0x1E
        case custom = 0x20

        public var title: String {
            switch self {
            case .standard: return "Standard"
            case .rtsRpg: return "RTS / RPG"
            case .fps: return "FPS"
            case .moba: return "MOBA"
            case .movie: return "Movie"
            case .reading: return "Reading"
            case .night: return "Night"
            case .eyeCare: return "Eye Care"
            case .macView: return "Mac View"
            case .eBook: return "E-Book"
            case .sRGB: return "sRGB"
            case .adobeRGB: return "Adobe RGB"
            case .dciP3: return "DCI-P3"
            case .dyDsULLFPS: return "DyDs / ULL FPS"
            case .dyDsLocalDimming: return "DyDs / Local Dimming"
            case .custom: return "Custom"
            }
        }
    }

    public enum ColorTemperature: UInt16, CaseIterable, Sendable {
        case warm = 5
        case natural = 6
        case cold = 8
        case user1 = 11
        case user2 = 12
        case user3 = 13

        public var title: String {
            switch self {
            case .warm: return "Warm"
            case .natural: return "Natural"
            case .cold: return "Cold"
            case .user1: return "User 1"
            case .user2: return "User 2"
            case .user3: return "User 3"
            }
        }
    }

    public enum NightVisionLevel: UInt16, CaseIterable, Sendable {
        case off = 0
        case level1 = 1
        case level2 = 2
        case autoLevel1 = 3
        case autoLevel2 = 4

        public var title: String {
            switch self {
            case .off: return "Close"
            case .level1: return "Level 1"
            case .level2: return "Level 2"
            case .autoLevel1: return "Auto L1"
            case .autoLevel2: return "Auto L2"
            }
        }
    }

    public enum OfficialGamma: UInt16, CaseIterable, Sendable {
        case gamma18 = 2
        case gamma20 = 4
        case gamma22 = 6
        case gamma24 = 8
        case gamma26 = 10
        case sCurve = 12

        public var title: String {
            switch self {
            case .gamma18: return "1.8"
            case .gamma20: return "2.0"
            case .gamma22: return "2.2"
            case .gamma24: return "2.4"
            case .gamma26: return "2.6"
            case .sCurve: return "S-curve"
            }
        }
    }

    /// Custom scene targets from the utility's Default/Custom page.
    ///
    /// The official app first writes Custom scene 0x20, then adjusts these
    /// targets in the same two-write protocol. These entries are binary-derived
    /// and still need on-panel picture verification.
    public enum CustomSceneTarget: String, CaseIterable, Sendable {
        case saturation
        case gamma
        case hue
        case nightVision
        case dynamicOverdrive
        case crEnhance
        case colorEnhance

        public var windowsSetting: WindowsSetting {
            switch self {
            case .saturation: return .customSceneSaturation
            case .gamma: return .customSceneGamma
            case .hue: return .customSceneHue
            case .nightVision: return .customSceneNightVision
            case .dynamicOverdrive: return .customSceneDynamicOverdrive
            case .crEnhance: return .customSceneCR
            case .colorEnhance: return .customSceneColor
            }
        }

        public var allowedRange: ClosedRange<Int> { windowsSetting.allowedRange }
    }

    public enum RGBOutputRange: UInt16, CaseIterable, Sendable {
        case auto = 0
        case limited = 1
        case full = 2

        public var title: String {
            switch self {
            case .auto: return "Auto"
            case .limited: return "Limited"
            case .full: return "Full"
            }
        }
    }

    public enum DynamicOverdriveLevel: UInt16, CaseIterable, Sendable {
        case off = 0, level1 = 1, level2 = 2, level3 = 3, topspeed = 4

        public var title: String {
            switch self {
            case .off: return "Off"
            case .topspeed: return "Topspeed"
            default: return "Level \(rawValue)"
            }
        }
    }

    public enum DyDsULLLevel: UInt16, CaseIterable, Sendable {
        case off = 2, level3 = 3, level4 = 4, level5 = 5, level6 = 6, level7 = 7, level8 = 8

        public var title: String {
            self == .off ? "Off" : "Level \(rawValue)"
        }
    }

    public enum LowBlueLightLevel: UInt16, CaseIterable, Sendable {
        case off = 0, level1 = 1, level2 = 2, level3 = 3, level4 = 4

        public var title: String {
            self == .off ? "Off" : "Level \(rawValue)"
        }
    }

    public enum SharpnessLevel: UInt16, CaseIterable, Sendable {
        case level0 = 0, level1 = 1, level2 = 2, level3 = 3, level4 = 4

        public var title: String {
            self == .level0 ? "Off" : "Level \(rawValue)"
        }
    }

    public enum Toggle: UInt16, CaseIterable, Sendable {
        case off = 0
        case on = 1

        public init(_ enabled: Bool) { self = enabled ? .on : .off }

        public var title: String { self == .on ? "On" : "Off" }
    }

    // MARK: - Official Game Assistant

    /// Selector values extracted from `pageGameAssistant::onRadioButtonClicked`.
    public enum GameAssistant {
        public enum RefreshPosition: UInt16, CaseIterable, Sendable {
            case topRight = 0, topLeft = 1, bottomRight = 2, bottomLeft = 3

            public var title: String {
                switch self {
                case .topRight: return "Top Right"
                case .topLeft: return "Top Left"
                case .bottomRight: return "Bottom Right"
                case .bottomLeft: return "Bottom Left"
                }
            }
        }

        public enum ScreenSize: UInt16, CaseIterable, Sendable {
            case fullGame = 0, wide = 1, inch25 = 2, inch27 = 3, inch32 = 4

            public var title: String {
                switch self {
                case .fullGame: return "Full Game"
                case .wide: return "Wide"
                case .inch25: return "25\""
                case .inch27: return "27\""
                case .inch32: return "32\""
                }
            }
        }

        public enum CrosshairShape: UInt16, CaseIterable, Sendable {
            case shape1 = 1, shape2 = 2, shape3 = 3, shape4 = 4, shape5 = 5, shape6 = 6

            public var title: String { "Shape \(rawValue)" }
        }

        public enum CrosshairColor: UInt16, CaseIterable, Sendable {
            case red = 0, yellow = 1, green = 2, cyan = 3, blue = 4, purple = 5, white = 6, automatic = 7

            public var title: String {
                switch self {
                case .red: return "Red"
                case .yellow: return "Yellow"
                case .green: return "Green"
                case .cyan: return "Cyan"
                case .blue: return "Blue"
                case .purple: return "Purple"
                case .white: return "White"
                case .automatic: return "Auto"
                }
            }
        }

        public enum Duration: UInt16, CaseIterable, Sendable {
            case minutes15 = 0, minutes30 = 1, minutes45 = 2, minutes60 = 3

            public var title: String {
                switch self {
                case .minutes15: return "15 min"
                case .minutes30: return "30 min"
                case .minutes45: return "45 min"
                case .minutes60: return "60 min"
                }
            }
        }

        public enum Position: UInt16, CaseIterable, Sendable {
            case topRight = 0, topLeft = 1, bottomRight = 2, bottomLeft = 3

            public var title: String {
                switch self {
                case .topRight: return "Top Right"
                case .topLeft: return "Top Left"
                case .bottomRight: return "Bottom Right"
                case .bottomLeft: return "Bottom Left"
                }
            }
        }

        public enum MagnifierSize: UInt16, CaseIterable, Sendable {
            case small = 1, medium = 2, large = 3

            public var title: String {
                switch self {
                case .small: return "Small"
                case .medium: return "Medium"
                case .large: return "Large"
                }
            }
        }

        public enum Magnification: UInt16, CaseIterable, Sendable {
            case x15 = 0, x2 = 1, x4 = 2

            public var title: String {
                switch self {
                case .x15: return "1.5x"
                case .x2: return "2x"
                case .x4: return "4x"
                }
            }
        }

        public enum MagnifierPosition: UInt16, CaseIterable, Sendable {
            case topRight = 0, topLeft = 1, bottomRight = 2, bottomLeft = 3, central = 4

            public var title: String {
                switch self {
                case .topRight: return "Top Right"
                case .topLeft: return "Top Left"
                case .bottomRight: return "Bottom Right"
                case .bottomLeft: return "Bottom Left"
                case .central: return "Central"
                }
            }
        }

        public enum HawkEyeLevel: UInt16, CaseIterable, Sendable {
            case off = 0, level1 = 1, level2 = 2, level3 = 3

            public var title: String {
                self == .off ? "Off" : "Level \(rawValue)"
            }
        }

        /// One Game Assistant request. Each case pairs a target with the only
        /// value type the official page offers for it.
        public enum Command: Equatable, Sendable {
            case refreshPosition(RefreshPosition)
            case screenSize(ScreenSize)
            case alignment(Toggle)
            case crosshair(Toggle)
            case crosshairShape(CrosshairShape)
            case crosshairColor(CrosshairColor)
            case stopwatch(Toggle)
            case stopwatchTime(Duration)
            case stopwatchPosition(Position)
            case gameTime(Toggle)
            case gameTimeValue(Duration)
            case gameTimePosition(Position)
            case magnifier(Toggle)
            case magnifierSize(MagnifierSize)
            case magnification(Magnification)
            case magnifierPosition(MagnifierPosition)
            case hawkEye(Toggle)
            case hawkEyeSize(MagnifierSize)
            case hawkEyeLevel(HawkEyeLevel)
            case hawkEyePosition(Position)
            case nightVision(NightVisionLevel)

            public var setting: WindowsSetting {
                switch self {
                case .refreshPosition: return .gameAssistantRefreshPosition
                case .screenSize: return .gameAssistantScreenSize
                case .alignment: return .gameAssistantAlignment
                case .crosshair: return .gameAssistantCrosshair
                case .crosshairShape: return .gameAssistantCrosshairShape
                case .crosshairColor: return .gameAssistantCrosshairColor
                case .stopwatch: return .gameAssistantStopwatch
                case .stopwatchTime: return .gameAssistantStopwatchTime
                case .stopwatchPosition: return .gameAssistantStopwatchPosition
                case .gameTime: return .gameAssistantGameTime
                case .gameTimeValue: return .gameAssistantGameTimeValue
                case .gameTimePosition: return .gameAssistantGameTimePosition
                case .magnifier: return .gameAssistantMagnifier
                case .magnifierSize: return .gameAssistantMagnifierSize
                case .magnification: return .gameAssistantMagnification
                case .magnifierPosition: return .gameAssistantMagnifierPosition
                case .hawkEye: return .gameAssistantHawkEye
                case .hawkEyeSize: return .gameAssistantHawkEyeSize
                case .hawkEyeLevel: return .gameAssistantHawkEyeLevel
                case .hawkEyePosition: return .gameAssistantHawkEyePosition
                case .nightVision: return .gameAssistantNightVision
                }
            }

            public var value: UInt16 {
                switch self {
                case let .refreshPosition(value): return value.rawValue
                case let .screenSize(value): return value.rawValue
                case let .alignment(value), let .crosshair(value), let .stopwatch(value),
                     let .gameTime(value), let .magnifier(value), let .hawkEye(value):
                    return value.rawValue
                case let .crosshairShape(value): return value.rawValue
                case let .crosshairColor(value): return value.rawValue
                case let .stopwatchTime(value), let .gameTimeValue(value): return value.rawValue
                case let .stopwatchPosition(value), let .gameTimePosition(value),
                     let .hawkEyePosition(value):
                    return value.rawValue
                case let .magnifierSize(value), let .hawkEyeSize(value): return value.rawValue
                case let .magnification(value): return value.rawValue
                case let .magnifierPosition(value): return value.rawValue
                case let .hawkEyeLevel(value): return value.rawValue
                case let .nightVision(value): return value.rawValue
                }
            }

            /// The official utility makes the first four overlays mutually
            /// exclusive: enabling one (or choosing a refresh-rate position)
            /// sends clear commands to the other three.
            static let exclusiveOverlays: [WindowsSetting] = [
                .gameAssistantRefreshPosition, .gameAssistantCrosshair,
                .gameAssistantStopwatch, .gameAssistantGameTime,
            ]

            public var clearedOverlays: [WindowsSetting] {
                switch self {
                case .refreshPosition, .crosshair(.on), .stopwatch(.on), .gameTime(.on):
                    return Self.exclusiveOverlays.filter { $0 != setting }
                default:
                    return []
                }
            }
        }
    }
}

