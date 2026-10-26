namespace TitanArmyControl.Core.Protocol;

public static class TitanArmyProfile
{
    public const string ModelName = "P275MV PLUS";
    public const ushort UsbCInput = 15;

    public enum Certainty
    {
        Verified,
        ReadOnlyObserved,
        Unverified,
        Refuted,
    }

    public sealed record RegisterInfo(byte Vcp, string Title, Certainty Certainty, string Note);

    public static IReadOnlyList<RegisterInfo> Registers { get; } =
    [
        new(VcpCode.Brightness, "Brightness", Certainty.Verified,
            "Hardware backlight; ignored while HDR is engaged."),
        new(VcpCode.Contrast, "Contrast", Certainty.Verified,
            "Writable with HDR off; locked while HDR is engaged."),
        new(VcpCode.RedGain, "Red Gain", Certainty.ReadOnlyObserved, "Read-back observed."),
        new(VcpCode.GreenGain, "Green Gain", Certainty.ReadOnlyObserved, "Read-back observed."),
        new(VcpCode.BlueGain, "Blue Gain", Certainty.ReadOnlyObserved, "Read-back observed."),
        new(VcpCode.Volume, "Volume", Certainty.Verified, "Writable while HDR is active."),
        new(VcpCode.Vendor.PictureMode, "Picture Mode", Certainty.ReadOnlyObserved,
            "Compatibility register; use Scene for controls."),
        new(VcpCode.Vendor.Overdrive, "Overdrive", Certainty.Verified,
            "Directly writable with read-back verification."),
        new(VcpCode.Vendor.LegacyHdrProbe, "Legacy HDR Probe", Certainty.ReadOnlyObserved,
            "Not the official monitor HDR control."),
        new(VcpCode.Vendor.SceneMode, "Scene Mode", Certainty.Unverified, "Selector 0x99 target."),
        new(VcpCode.Vendor.ColorTemperature, "Color Temperature", Certainty.Unverified,
            "Selector 0x99 target."),
        new(VcpCode.Vendor.AdaptiveSync, "Adaptive-Sync", Certainty.Unverified,
            "Selector 0x99 target."),
        new(VcpCode.Vendor.LowBlueLight, "Low Blue Light", Certainty.Unverified,
            "Selector 0x99 target."),
        new(VcpCode.Vendor.NightVision, "Night Vision", Certainty.Unverified,
            "Selector 0x99 target."),
        new(VcpCode.Vendor.DynamicOverdrive, "Dynamic OD", Certainty.Unverified,
            "Selector 0x99 target."),
        new(VcpCode.Vendor.Sharpness, "Sharpness", Certainty.Unverified,
            "Selector 0x99 target."),
        new(VcpCode.Vendor.DyDsUll, "DyDs / ULL", Certainty.Unverified,
            "Selector 0x99 target."),
        new(VcpCode.Vendor.Gamma, "Official Gamma", Certainty.Unverified,
            "Selector 0x99 target."),
        new(VcpCode.Vendor.GameRush, "Game Rush", Certainty.Unverified,
            "Selector 0x99 target."),
        new(VcpCode.Vendor.ColorEnhance, "Color Enhance", Certainty.Unverified,
            "Official range 0-10."),
        new(VcpCode.Vendor.CrEnhance, "CR Enhance", Certainty.Unverified,
            "Official range 0-5."),
        new(VcpCode.Vendor.ShadowBalance, "Shadow Balance", Certainty.Unverified,
            "Official range 0-100."),
        new(VcpCode.Vendor.SuperResolution, "Super Resolution", Certainty.Unverified,
            "Official range 0-5."),
        new(VcpCode.Vendor.HaloControl, "Halo Control", Certainty.Unverified,
            "Official range 0-100."),
        new(VcpCode.Vendor.RgbOutputRange, "RGB Output Range", Certainty.Unverified,
            "Auto, Limited, or Full."),
        new(VcpCode.Vendor.ScreenMode, "Screen Mode", Certainty.Unverified,
            "Encoding not confirmed."),
        new(VcpCode.Vendor.DisplayMode, "0x3A Mode", Certainty.Refuted,
            "This is not the dual-mode selector."),
    ];

    public static RegisterInfo? Register(byte vcp) => Registers.FirstOrDefault(x => x.Vcp == vcp);

    public enum WindowsSetting
    {
        SceneMode,
        ColorTemperature,
        HdrMode,
        LocalDimming,
        DynamicOverdrive,
        DyDsUll,
        NightVision,
        Sharpness,
        LowBlueLight,
        AdaptiveSync,
        Gamma,
        GameRush,
        ColorEnhance,
        CrEnhance,
        ShadowBalance,
        SuperResolution,
        HaloControl,
        RgbOutputRange,
        GameAssistantRefreshPosition,
        GameAssistantScreenSize,
        GameAssistantAlignment,
        GameAssistantCrosshair,
        GameAssistantCrosshairShape,
        GameAssistantCrosshairColor,
        GameAssistantStopwatch,
        GameAssistantStopwatchTime,
        GameAssistantStopwatchPosition,
        GameAssistantGameTime,
        GameAssistantGameTimeValue,
        GameAssistantGameTimePosition,
        GameAssistantMagnifier,
        GameAssistantMagnifierSize,
        GameAssistantMagnification,
        GameAssistantMagnifierPosition,
        GameAssistantHawkEye,
        GameAssistantHawkEyeSize,
        GameAssistantHawkEyeLevel,
        GameAssistantHawkEyePosition,
        GameAssistantNightVision,
        CustomSceneSaturation,
        CustomSceneGamma,
        CustomSceneHue,
        CustomSceneNightVision,
        CustomSceneDynamicOverdrive,
        CustomSceneCr,
        CustomSceneColor,
    }

    public static byte Register(this WindowsSetting setting) => setting switch
    {
        WindowsSetting.SceneMode => VcpCode.Vendor.SceneMode,
        WindowsSetting.ColorTemperature => VcpCode.Vendor.ColorTemperature,
        WindowsSetting.HdrMode => VcpCode.Vendor.HdrMode,
        WindowsSetting.LocalDimming => VcpCode.Vendor.LocalDimming,
        WindowsSetting.DynamicOverdrive => VcpCode.Vendor.DynamicOverdrive,
        WindowsSetting.DyDsUll => VcpCode.Vendor.DyDsUll,
        WindowsSetting.NightVision => VcpCode.Vendor.NightVision,
        WindowsSetting.Sharpness => VcpCode.Vendor.Sharpness,
        WindowsSetting.LowBlueLight => VcpCode.Vendor.LowBlueLight,
        WindowsSetting.AdaptiveSync => VcpCode.Vendor.AdaptiveSync,
        WindowsSetting.Gamma => VcpCode.Vendor.Gamma,
        WindowsSetting.GameRush => VcpCode.Vendor.GameRush,
        WindowsSetting.ColorEnhance => VcpCode.Vendor.ColorEnhance,
        WindowsSetting.CrEnhance => VcpCode.Vendor.CrEnhance,
        WindowsSetting.ShadowBalance => VcpCode.Vendor.ShadowBalance,
        WindowsSetting.SuperResolution => VcpCode.Vendor.SuperResolution,
        WindowsSetting.HaloControl => VcpCode.Vendor.HaloControl,
        WindowsSetting.RgbOutputRange => VcpCode.Vendor.RgbOutputRange,
        WindowsSetting.GameAssistantRefreshPosition => VcpCode.Vendor.GameAssistantRefreshPosition,
        WindowsSetting.GameAssistantScreenSize => VcpCode.Vendor.GameAssistantScreenSize,
        WindowsSetting.GameAssistantAlignment => VcpCode.Vendor.GameAssistantAlignmentEnable,
        WindowsSetting.GameAssistantCrosshair => VcpCode.Vendor.GameAssistantCrosshairEnable,
        WindowsSetting.GameAssistantCrosshairShape => VcpCode.Vendor.GameAssistantCrosshairShape,
        WindowsSetting.GameAssistantCrosshairColor => VcpCode.Vendor.GameAssistantCrosshairColor,
        WindowsSetting.GameAssistantStopwatch => VcpCode.Vendor.GameAssistantStopwatchEnable,
        WindowsSetting.GameAssistantStopwatchTime => VcpCode.Vendor.GameAssistantStopwatchTime,
        WindowsSetting.GameAssistantStopwatchPosition => VcpCode.Vendor.GameAssistantStopwatchPosition,
        WindowsSetting.GameAssistantGameTime => VcpCode.Vendor.GameAssistantGameTimeEnable,
        WindowsSetting.GameAssistantGameTimeValue => VcpCode.Vendor.GameAssistantGameTime,
        WindowsSetting.GameAssistantGameTimePosition => VcpCode.Vendor.GameAssistantGameTimePosition,
        WindowsSetting.GameAssistantMagnifier => VcpCode.Vendor.GameAssistantMagnifierEnable,
        WindowsSetting.GameAssistantMagnifierSize => VcpCode.Vendor.GameAssistantMagnifierSize,
        WindowsSetting.GameAssistantMagnification => VcpCode.Vendor.GameAssistantMagnification,
        WindowsSetting.GameAssistantMagnifierPosition => VcpCode.Vendor.GameAssistantMagnifierPosition,
        WindowsSetting.GameAssistantHawkEye => VcpCode.Vendor.GameAssistantHawkEyeEnable,
        WindowsSetting.GameAssistantHawkEyeSize => VcpCode.Vendor.GameAssistantHawkEyeSize,
        WindowsSetting.GameAssistantHawkEyeLevel => VcpCode.Vendor.GameAssistantHawkEyeLevel,
        WindowsSetting.GameAssistantHawkEyePosition => VcpCode.Vendor.GameAssistantHawkEyePosition,
        WindowsSetting.GameAssistantNightVision => VcpCode.Vendor.GameAssistantNightVisionEnable,
        WindowsSetting.CustomSceneSaturation => VcpCode.Vendor.CustomScene.Saturation,
        WindowsSetting.CustomSceneGamma => VcpCode.Vendor.CustomScene.Gamma,
        WindowsSetting.CustomSceneHue => VcpCode.Vendor.CustomScene.Hue,
        WindowsSetting.CustomSceneNightVision => VcpCode.Vendor.CustomScene.NightVision,
        WindowsSetting.CustomSceneDynamicOverdrive => VcpCode.Vendor.CustomScene.DynamicOverdrive,
        WindowsSetting.CustomSceneCr => VcpCode.Vendor.CustomScene.CrEnhance,
        WindowsSetting.CustomSceneColor => VcpCode.Vendor.CustomScene.ColorEnhance,
        _ => throw new ArgumentOutOfRangeException(nameof(setting)),
    };

    public static IntRange AllowedRange(this WindowsSetting setting) => setting switch
    {
        WindowsSetting.CrEnhance or WindowsSetting.SuperResolution or
            WindowsSetting.CustomSceneGamma => new(0, 5),
        WindowsSetting.CustomSceneNightVision => new(0, 4),
        WindowsSetting.ColorEnhance or WindowsSetting.CustomSceneDynamicOverdrive or
            WindowsSetting.CustomSceneCr or WindowsSetting.CustomSceneColor => new(0, 10),
        WindowsSetting.ShadowBalance or WindowsSetting.HaloControl or
            WindowsSetting.CustomSceneSaturation or WindowsSetting.CustomSceneHue => new(0, 100),
        _ => new(0, 255),
    };

    public static string ContractKey(this WindowsSetting setting) => setting switch
    {
        WindowsSetting.SceneMode => "scene",
        WindowsSetting.HdrMode => "hdr",
        WindowsSetting.DyDsUll => "dyDsULL",
        WindowsSetting.CustomSceneCr => "customSceneCR",
        _ => char.ToLowerInvariant(setting.ToString()[0]) + setting.ToString()[1..],
    };

    public static TimeSpan SettleDelay(this WindowsSetting setting) =>
        setting == WindowsSetting.HdrMode ? TimeSpan.FromSeconds(1.5) : TimeSpan.FromMilliseconds(200);

    public readonly record struct IntRange(int Minimum, int Maximum)
    {
        public bool Contains(int value) => value >= Minimum && value <= Maximum;
    }

    public enum Enhancement
    {
        ColorEnhance,
        CrEnhance,
        ShadowBalance,
        SuperResolution,
        HaloControl,
    }

    public static WindowsSetting Setting(this Enhancement enhancement) => enhancement switch
    {
        Enhancement.ColorEnhance => WindowsSetting.ColorEnhance,
        Enhancement.CrEnhance => WindowsSetting.CrEnhance,
        Enhancement.ShadowBalance => WindowsSetting.ShadowBalance,
        Enhancement.SuperResolution => WindowsSetting.SuperResolution,
        Enhancement.HaloControl => WindowsSetting.HaloControl,
        _ => throw new ArgumentOutOfRangeException(nameof(enhancement)),
    };

    public enum LocalDimming : ushort
    {
        Off = 2,
        Low = 3,
        Smooth = 4,
        Medium = 5,
        High = 6,
    }

    public enum VendorHdr : ushort
    {
        Off = 0,
        Auto = 1,
        Game = 2,
        Movie = 3,
    }

    public enum Overdrive : ushort
    {
        Off = 0,
        Normal = 1,
        Fast = 2,
        Fastest = 3,
    }

    public enum SceneMode : ushort
    {
        Standard = 0x02,
        RtsRpg = 0x04,
        Fps = 0x06,
        Moba = 0x08,
        Movie = 0x0A,
        Reading = 0x0C,
        Night = 0x0E,
        EyeCare = 0x10,
        MacView = 0x12,
        EBook = 0x14,
        Srgb = 0x16,
        AdobeRgb = 0x18,
        DciP3 = 0x1A,
        DyDsUllFps = 0x1C,
        DyDsLocalDimming = 0x1E,
        Custom = 0x20,
    }

    public enum ColorTemperature : ushort
    {
        Warm = 5,
        Natural = 6,
        Cold = 8,
        User1 = 11,
        User2 = 12,
        User3 = 13,
    }

    public enum NightVisionLevel : ushort
    {
        Off = 0,
        Level1 = 1,
        Level2 = 2,
        AutoLevel1 = 3,
        AutoLevel2 = 4,
    }

    public enum OfficialGamma : ushort
    {
        Gamma18 = 2,
        Gamma20 = 4,
        Gamma22 = 6,
        Gamma24 = 8,
        Gamma26 = 10,
        SCurve = 12,
    }

    public enum CustomSceneTarget
    {
        Saturation,
        Gamma,
        Hue,
        NightVision,
        DynamicOverdrive,
        CrEnhance,
        ColorEnhance,
    }

    public static WindowsSetting Setting(this CustomSceneTarget target) => target switch
    {
        CustomSceneTarget.Saturation => WindowsSetting.CustomSceneSaturation,
        CustomSceneTarget.Gamma => WindowsSetting.CustomSceneGamma,
        CustomSceneTarget.Hue => WindowsSetting.CustomSceneHue,
        CustomSceneTarget.NightVision => WindowsSetting.CustomSceneNightVision,
        CustomSceneTarget.DynamicOverdrive => WindowsSetting.CustomSceneDynamicOverdrive,
        CustomSceneTarget.CrEnhance => WindowsSetting.CustomSceneCr,
        CustomSceneTarget.ColorEnhance => WindowsSetting.CustomSceneColor,
        _ => throw new ArgumentOutOfRangeException(nameof(target)),
    };

    public enum RgbOutputRange : ushort
    {
        Auto = 0,
        Limited = 1,
        Full = 2,
    }

    public enum DynamicOverdriveLevel : ushort
    {
        Off = 0,
        Level1 = 1,
        Level2 = 2,
        Level3 = 3,
        Topspeed = 4,
    }

    public enum DyDsUllLevel : ushort
    {
        Off = 2,
        Level3 = 3,
        Level4 = 4,
        Level5 = 5,
        Level6 = 6,
        Level7 = 7,
        Level8 = 8,
    }

    public enum LowBlueLightLevel : ushort
    {
        Off = 0,
        Level1 = 1,
        Level2 = 2,
        Level3 = 3,
        Level4 = 4,
    }

    public enum SharpnessLevel : ushort
    {
        Off = 0,
        Level1 = 1,
        Level2 = 2,
        Level3 = 3,
        Level4 = 4,
    }

    public enum Toggle : ushort
    {
        Off = 0,
        On = 1,
    }

    public static Toggle ToToggle(this bool enabled) => enabled ? Toggle.On : Toggle.Off;

    public static class GameAssistant
    {
        public enum RefreshPosition : ushort
        {
            TopRight = 0,
            TopLeft = 1,
            BottomRight = 2,
            BottomLeft = 3,
        }

        public enum ScreenSize : ushort
        {
            FullGame = 0,
            Wide = 1,
            Inch25 = 2,
            Inch27 = 3,
            Inch32 = 4,
        }

        public enum CrosshairShape : ushort
        {
            Shape1 = 1,
            Shape2 = 2,
            Shape3 = 3,
            Shape4 = 4,
            Shape5 = 5,
            Shape6 = 6,
        }

        public enum CrosshairColor : ushort
        {
            Red = 0,
            Yellow = 1,
            Green = 2,
            Cyan = 3,
            Blue = 4,
            Purple = 5,
            White = 6,
            Automatic = 7,
        }

        public enum Duration : ushort
        {
            Minutes15 = 0,
            Minutes30 = 1,
            Minutes45 = 2,
            Minutes60 = 3,
        }

        public enum Position : ushort
        {
            TopRight = 0,
            TopLeft = 1,
            BottomRight = 2,
            BottomLeft = 3,
        }

        public enum MagnifierSize : ushort
        {
            Small = 1,
            Medium = 2,
            Large = 3,
        }

        public enum Magnification : ushort
        {
            X15 = 0,
            X2 = 1,
            X4 = 2,
        }

        public enum MagnifierPosition : ushort
        {
            TopRight = 0,
            TopLeft = 1,
            BottomRight = 2,
            BottomLeft = 3,
            Central = 4,
        }

        public enum HawkEyeLevel : ushort
        {
            Off = 0,
            Level1 = 1,
            Level2 = 2,
            Level3 = 3,
        }

        public abstract record Command
        {
            public abstract WindowsSetting Setting { get; }
            public abstract ushort Value { get; }
            public virtual IReadOnlyList<WindowsSetting> ClearedOverlays => [];

            private static readonly WindowsSetting[] ExclusiveOverlays =
            [
                WindowsSetting.GameAssistantRefreshPosition,
                WindowsSetting.GameAssistantCrosshair,
                WindowsSetting.GameAssistantStopwatch,
                WindowsSetting.GameAssistantGameTime,
            ];

            protected static IReadOnlyList<WindowsSetting> ClearOthers(WindowsSetting selected) =>
                ExclusiveOverlays.Where(x => x != selected).ToArray();

            public sealed record RefreshPositionValue(RefreshPosition TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantRefreshPosition;
                public override ushort Value => (ushort)TypedValue;
                public override IReadOnlyList<WindowsSetting> ClearedOverlays =>
                    ClearOthers(Setting);
            }

            public sealed record ScreenSizeValue(ScreenSize TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantScreenSize;
                public override ushort Value => (ushort)TypedValue;
            }

            public sealed record AlignmentValue(Toggle TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantAlignment;
                public override ushort Value => (ushort)TypedValue;
            }

            public sealed record CrosshairValue(Toggle TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantCrosshair;
                public override ushort Value => (ushort)TypedValue;
                public override IReadOnlyList<WindowsSetting> ClearedOverlays =>
                    TypedValue == Toggle.On ? ClearOthers(Setting) : [];
            }

            public sealed record CrosshairShapeValue(CrosshairShape TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantCrosshairShape;
                public override ushort Value => (ushort)TypedValue;
            }

            public sealed record CrosshairColorValue(CrosshairColor TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantCrosshairColor;
                public override ushort Value => (ushort)TypedValue;
            }

            public sealed record StopwatchValue(Toggle TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantStopwatch;
                public override ushort Value => (ushort)TypedValue;
                public override IReadOnlyList<WindowsSetting> ClearedOverlays =>
                    TypedValue == Toggle.On ? ClearOthers(Setting) : [];
            }

            public sealed record StopwatchTimeValue(Duration TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantStopwatchTime;
                public override ushort Value => (ushort)TypedValue;
            }

            public sealed record StopwatchPositionValue(Position TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantStopwatchPosition;
                public override ushort Value => (ushort)TypedValue;
            }

            public sealed record GameTimeValue(Toggle TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantGameTime;
                public override ushort Value => (ushort)TypedValue;
                public override IReadOnlyList<WindowsSetting> ClearedOverlays =>
                    TypedValue == Toggle.On ? ClearOthers(Setting) : [];
            }

            public sealed record GameTimeDurationValue(Duration TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantGameTimeValue;
                public override ushort Value => (ushort)TypedValue;
            }

            public sealed record GameTimePositionValue(Position TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantGameTimePosition;
                public override ushort Value => (ushort)TypedValue;
            }

            public sealed record MagnifierValue(Toggle TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantMagnifier;
                public override ushort Value => (ushort)TypedValue;
            }

            public sealed record MagnifierSizeValue(MagnifierSize TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantMagnifierSize;
                public override ushort Value => (ushort)TypedValue;
            }

            public sealed record MagnificationValue(Magnification TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantMagnification;
                public override ushort Value => (ushort)TypedValue;
            }

            public sealed record MagnifierPositionValue(MagnifierPosition TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantMagnifierPosition;
                public override ushort Value => (ushort)TypedValue;
            }

            public sealed record HawkEyeValue(Toggle TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantHawkEye;
                public override ushort Value => (ushort)TypedValue;
            }

            public sealed record HawkEyeSizeValue(MagnifierSize TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantHawkEyeSize;
                public override ushort Value => (ushort)TypedValue;
            }

            public sealed record HawkEyeLevelValue(HawkEyeLevel TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantHawkEyeLevel;
                public override ushort Value => (ushort)TypedValue;
            }

            public sealed record HawkEyePositionValue(Position TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantHawkEyePosition;
                public override ushort Value => (ushort)TypedValue;
            }

            public sealed record NightVisionValue(NightVisionLevel TypedValue) : Command
            {
                public override WindowsSetting Setting => WindowsSetting.GameAssistantNightVision;
                public override ushort Value => (ushort)TypedValue;
            }
        }
    }
}
