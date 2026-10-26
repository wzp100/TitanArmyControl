import Foundation

/// VCP codes referenced by this project.
///
/// Only codes whose meaning is either standardised by DDC/CI or verified against
/// this panel are listed. Anything else is deliberately absent: unknown
/// registers are never written.
public enum VCPCode {
    public static let brightness: UInt8 = 0x10
    public static let contrast: UInt8 = 0x12
    /// DDC/CI "select color preset"; this panel maps it to a 0...12 gamma
    /// selector. Confirmed by read/write on the P275MV PLUS.
    public static let gamma: UInt8 = 0x14
    public static let redGain: UInt8 = 0x16
    public static let greenGain: UInt8 = 0x18
    public static let blueGain: UInt8 = 0x1A
    public static let volume: UInt8 = 0x62
    public static let mute: UInt8 = 0x8D
    public static let inputSource: UInt8 = 0x60
    public static let powerMode: UInt8 = 0xD6
    public static let displayUsageTime: UInt8 = 0xC0

    /// Vendor-specific and official control targets. Values that look like
    /// conventional DDC codes are reached only through selector 0x99.
    public enum Vendor {
        /// HKC/Titan Army command preamble reused from a reserved MCCS code.
        public static let selector: UInt8 = 0x99
        public static let pictureMode: UInt8 = 0xE0
        public static let overdrive: UInt8 = 0xE1
        public static let legacyHDRProbe: UInt8 = 0xE2
        public static let hdrMode: UInt8 = 0x4A
        public static let screenMode: UInt8 = 0xF3
        /// Historically mislabelled as "Full Game / dual mode" by the Windows UI.
        public static let displayMode: UInt8 = 0x3A
        /// Official scene-mode target. Despite the DDC-looking value, the
        /// Windows utility reaches it only through the 0x99 selector.
        public static let sceneMode: UInt8 = 0x22
        public static let colorTemperature: UInt8 = 0x14
        public static let gamma: UInt8 = 0x26
        public static let gameRush: UInt8 = 0x43
        public static let colorEnhance: UInt8 = 0x40
        public static let crEnhance: UInt8 = 0x41
        public static let shadowBalance: UInt8 = 0x42
        public static let superResolution: UInt8 = 0x44
        public static let adaptiveSync: UInt8 = 0xE4
        public static let lowBlueLight: UInt8 = 0xD8
        public static let nightVision: UInt8 = 0x66
        public static let dynamicOverdrive: UInt8 = 0x49
        public static let sharpness: UInt8 = 0x87
        public static let dyDsULL: UInt8 = 0x48
        public static let haloControl: UInt8 = 0x9D
        public static let rgbOutputRange: UInt8 = 0x55
        public static let localDimming: UInt8 = 0x47

        /// Custom scene targets. The official page applies them only after
        /// selecting Custom scene value 0x20.
        public enum CustomScene {
            public static let saturation: UInt8 = 0x59
            public static let gamma: UInt8 = 0x5A
            public static let hue: UInt8 = 0x5B
            public static let nightVision: UInt8 = 0x56
            public static let dynamicOverdrive: UInt8 = 0x49
            public static let crEnhance: UInt8 = 0x41
            public static let colorEnhance: UInt8 = 0x40
        }

        // Game Assistant command values. The utility sends these to 0x99 and
        // repeats them to the same target; they are command indexes, not
        // conventional VCP features.
        public static let gameAssistantRefreshPosition: UInt8 = 0x84
        public static let gameAssistantCrosshairColor: UInt8 = 0x86
        public static let gameAssistantCrosshairShape: UInt8 = 0x88
        public static let gameAssistantStopwatchTime: UInt8 = 0x8A
        public static let gameAssistantStopwatchPosition: UInt8 = 0x8E
        public static let gameAssistantGameTime: UInt8 = 0x90
        public static let gameAssistantGameTimePosition: UInt8 = 0x92
        public static let gameAssistantMagnifierPosition: UInt8 = 0x94
        public static let gameAssistantScreenSize: UInt8 = 0xA6
        public static let gameAssistantAlignmentEnable: UInt8 = 0xA8
        public static let gameAssistantCrosshairEnable: UInt8 = 0x74
        public static let gameAssistantStopwatchEnable: UInt8 = 0x78
        public static let gameAssistantGameTimeEnable: UInt8 = 0x7A
        public static let gameAssistantMagnifierEnable: UInt8 = 0x9E
        public static let gameAssistantHawkEyeEnable: UInt8 = 0x91
        public static let gameAssistantNightVisionEnable: UInt8 = 0x80
        public static let gameAssistantHawkEyeSize: UInt8 = 0x9A
        public static let gameAssistantHawkEyePosition: UInt8 = 0x99
        public static let gameAssistantHawkEyeLevel: UInt8 = 0x92
        public static let gameAssistantMagnifierSize: UInt8 = 0x9C
        public static let gameAssistantMagnification: UInt8 = 0xB0
    }
}

/// Human-readable labels for VCP codes used in diagnostics.
public enum VCPName {
    public static func of(_ vcp: UInt8) -> String {
        switch vcp {
        case VCPCode.brightness: return "Brightness"
        case VCPCode.contrast: return "Contrast"
        case VCPCode.gamma: return "Gamma"
        case VCPCode.redGain: return "Red Gain"
        case VCPCode.greenGain: return "Green Gain"
        case VCPCode.blueGain: return "Blue Gain"
        case VCPCode.volume: return "Volume"
        case VCPCode.mute: return "Mute"
        case VCPCode.inputSource: return "Input Source"
        case VCPCode.powerMode: return "Power Mode"
        case VCPCode.displayUsageTime: return "Usage Time"
        case VCPCode.Vendor.pictureMode: return "Picture Mode (vendor)"
        case VCPCode.Vendor.overdrive: return "Overdrive (vendor)"
        case VCPCode.Vendor.hdrMode: return "HDR Mode (vendor)"
        case VCPCode.Vendor.legacyHDRProbe: return "Legacy HDR Probe"
        case VCPCode.Vendor.screenMode: return "Screen Mode (vendor)"
        case VCPCode.Vendor.displayMode: return "Display Mode (vendor 0x3A)"
        case VCPCode.Vendor.sceneMode: return "Scene Mode (vendor)"
        case VCPCode.Vendor.colorTemperature: return "Color Temperature (vendor)"
        case VCPCode.Vendor.gamma: return "Gamma (vendor)"
        case VCPCode.Vendor.gameRush: return "Game Rush (vendor)"
        case VCPCode.Vendor.colorEnhance: return "Color Enhance (vendor)"
        case VCPCode.Vendor.crEnhance: return "CR Enhance (vendor)"
        case VCPCode.Vendor.shadowBalance: return "Shadow Balance (vendor)"
        case VCPCode.Vendor.superResolution: return "Super Resolution (vendor)"
        case VCPCode.Vendor.adaptiveSync: return "Adaptive-Sync (vendor)"
        case VCPCode.Vendor.lowBlueLight: return "Low Blue Light (vendor)"
        case VCPCode.Vendor.nightVision: return "Night Vision (vendor)"
        case VCPCode.Vendor.dynamicOverdrive: return "Dynamic Overdrive (vendor)"
        case VCPCode.Vendor.sharpness: return "Sharpness (vendor)"
        case VCPCode.Vendor.dyDsULL: return "DyDs / ULL (vendor)"
        case VCPCode.Vendor.haloControl: return "Halo Control (vendor)"
        case VCPCode.Vendor.rgbOutputRange: return "RGB Output Range (vendor)"
        case VCPCode.Vendor.localDimming: return "Local Dimming (vendor)"
        default: return String(format: "VCP 0x%02X", vcp)
        }
    }
}
