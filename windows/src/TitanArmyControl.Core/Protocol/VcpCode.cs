namespace TitanArmyControl.Core.Protocol;

/// <summary>
/// VCP codes verified for the P275MV PLUS. Unknown registers are deliberately
/// absent and must never be written by application code.
/// </summary>
public static class VcpCode
{
    public const byte Brightness = 0x10;
    public const byte Contrast = 0x12;
    public const byte Gamma = 0x14;
    public const byte RedGain = 0x16;
    public const byte GreenGain = 0x18;
    public const byte BlueGain = 0x1A;
    public const byte Volume = 0x62;
    public const byte Mute = 0x8D;
    public const byte InputSource = 0x60;
    public const byte PowerMode = 0xD6;
    public const byte DisplayUsageTime = 0xC0;

    public static class Vendor
    {
        public const byte Selector = 0x99;
        public const byte PictureMode = 0xE0;
        public const byte Overdrive = 0xE1;
        public const byte LegacyHdrProbe = 0xE2;
        public const byte HdrMode = 0x4A;
        public const byte ScreenMode = 0xF3;
        public const byte DisplayMode = 0x3A;
        public const byte SceneMode = 0x22;
        public const byte ColorTemperature = 0x14;
        public const byte Gamma = 0x26;
        public const byte GameRush = 0x43;
        public const byte ColorEnhance = 0x40;
        public const byte CrEnhance = 0x41;
        public const byte ShadowBalance = 0x42;
        public const byte SuperResolution = 0x44;
        public const byte AdaptiveSync = 0xE4;
        public const byte LowBlueLight = 0xD8;
        public const byte NightVision = 0x66;
        public const byte DynamicOverdrive = 0x49;
        public const byte Sharpness = 0x87;
        public const byte DyDsUll = 0x48;
        public const byte HaloControl = 0x9D;
        public const byte RgbOutputRange = 0x55;
        public const byte LocalDimming = 0x47;

        public static class CustomScene
        {
            public const byte Saturation = 0x59;
            public const byte Gamma = 0x5A;
            public const byte Hue = 0x5B;
            public const byte NightVision = 0x56;
            public const byte DynamicOverdrive = 0x49;
            public const byte CrEnhance = 0x41;
            public const byte ColorEnhance = 0x40;
        }

        public const byte GameAssistantRefreshPosition = 0x84;
        public const byte GameAssistantCrosshairColor = 0x86;
        public const byte GameAssistantCrosshairShape = 0x88;
        public const byte GameAssistantStopwatchTime = 0x8A;
        public const byte GameAssistantStopwatchPosition = 0x8E;
        public const byte GameAssistantGameTime = 0x90;
        public const byte GameAssistantGameTimePosition = 0x92;
        public const byte GameAssistantMagnifierPosition = 0x94;
        public const byte GameAssistantScreenSize = 0xA6;
        public const byte GameAssistantAlignmentEnable = 0xA8;
        public const byte GameAssistantCrosshairEnable = 0x74;
        public const byte GameAssistantStopwatchEnable = 0x78;
        public const byte GameAssistantGameTimeEnable = 0x7A;
        public const byte GameAssistantMagnifierEnable = 0x9E;
        public const byte GameAssistantHawkEyeEnable = 0x91;
        public const byte GameAssistantNightVisionEnable = 0x80;
        public const byte GameAssistantHawkEyeSize = 0x9A;
        public const byte GameAssistantHawkEyePosition = 0x99;
        public const byte GameAssistantHawkEyeLevel = 0x92;
        public const byte GameAssistantMagnifierSize = 0x9C;
        public const byte GameAssistantMagnification = 0xB0;
    }
}
