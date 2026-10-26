using System.Diagnostics;
using Microsoft.UI.Reactor;
using Microsoft.UI.Reactor.Core;
using static Microsoft.UI.Reactor.Factories;
using static Microsoft.UI.Reactor.Core.Theme;
using TitanArmyControl.Core.Application;
using TitanArmyControl.Core.Controller;
using TitanArmyControl.Core.Model;
using TitanArmyControl.Core.Protocol;

namespace TitanArmyControl.Windows;

internal static class Pages
{
    private static readonly TitanArmyProfile.SceneMode[] Scenes =
        Enum.GetValues<TitanArmyProfile.SceneMode>();

    private static readonly TitanArmyProfile.ColorTemperature[] ColorTemperatures =
        Enum.GetValues<TitanArmyProfile.ColorTemperature>();

    private static readonly TitanArmyProfile.VendorHdr[] VendorHdrModes =
        Enum.GetValues<TitanArmyProfile.VendorHdr>();

    private static readonly TitanArmyProfile.LocalDimming[] LocalDimmingLevels =
        Enum.GetValues<TitanArmyProfile.LocalDimming>();

    private static readonly TitanArmyProfile.OfficialGamma[] GammaLevels =
        Enum.GetValues<TitanArmyProfile.OfficialGamma>();

    private static readonly TitanArmyProfile.DynamicOverdriveLevel[] DynamicOverdriveLevels =
        Enum.GetValues<TitanArmyProfile.DynamicOverdriveLevel>();

    private static readonly TitanArmyProfile.DyDsUllLevel[] DyDsLevels =
        Enum.GetValues<TitanArmyProfile.DyDsUllLevel>();

    private static readonly TitanArmyProfile.LowBlueLightLevel[] LowBlueLevels =
        Enum.GetValues<TitanArmyProfile.LowBlueLightLevel>();

    private static readonly TitanArmyProfile.SharpnessLevel[] SharpnessLevels =
        Enum.GetValues<TitanArmyProfile.SharpnessLevel>();

    private static readonly TitanArmyProfile.RgbOutputRange[] OutputRanges =
        Enum.GetValues<TitanArmyProfile.RgbOutputRange>();

    private static readonly TitanArmyProfile.GameAssistant.CrosshairShape[] CrosshairShapes =
        Enum.GetValues<TitanArmyProfile.GameAssistant.CrosshairShape>();

    private static readonly TitanArmyProfile.GameAssistant.CrosshairColor[] CrosshairColors =
        Enum.GetValues<TitanArmyProfile.GameAssistant.CrosshairColor>();

    private static readonly TitanArmyProfile.GameAssistant.Duration[] Durations =
        Enum.GetValues<TitanArmyProfile.GameAssistant.Duration>();

    private static readonly TitanArmyProfile.GameAssistant.Position[] Positions =
        Enum.GetValues<TitanArmyProfile.GameAssistant.Position>();

    private static readonly TitanArmyProfile.GameAssistant.MagnifierSize[] MagnifierSizes =
        Enum.GetValues<TitanArmyProfile.GameAssistant.MagnifierSize>();

    private static readonly TitanArmyProfile.GameAssistant.Magnification[] Magnifications =
        Enum.GetValues<TitanArmyProfile.GameAssistant.Magnification>();

    private static readonly TitanArmyProfile.GameAssistant.MagnifierPosition[] MagnifierPositions =
        Enum.GetValues<TitanArmyProfile.GameAssistant.MagnifierPosition>();

    private static readonly TitanArmyProfile.GameAssistant.HawkEyeLevel[] HawkEyeLevels =
        Enum.GetValues<TitanArmyProfile.GameAssistant.HawkEyeLevel>();

    private static readonly TitanArmyProfile.GameAssistant.ScreenSize[] ScreenSizes =
        Enum.GetValues<TitanArmyProfile.GameAssistant.ScreenSize>();

    private static readonly TitanArmyProfile.GameAssistant.RefreshPosition[] RefreshPositions =
        Enum.GetValues<TitanArmyProfile.GameAssistant.RefreshPosition>();

    public static Element Build(
        string page,
        string language,
        MonitorApplicationState state,
        PlatformCapabilities capabilities,
        Action<Action<MonitorController>> apply) =>
        page switch
        {
            "scene" => ScenePage(language, state, apply),
            "game" => GamePage(language, state, capabilities, apply),
            "dark" => DarkPage(language, capabilities),
            "basic" => BasicPage(language, state, apply),
            "oled" => OledPage(language, state, apply, capabilities),
            "support" => SupportPage(language, state),
            "store" => StorePage(language),
            _ => BasicPage(language, state, apply),
        };

    private static Element ScenePage(
        string language,
        MonitorApplicationState state,
        Action<Action<MonitorController>> apply) =>
        VStack(
            16,
            UiComponents.Card(
                T(language, "scene"),
                T(language, "sceneDesc"),
                ComboBox(
                    Scenes.Select(scene => SceneLabel(scene, language)).ToArray(),
                    IndexOf(Scenes, TitanArmyProfile.SceneMode.Standard),
                    index => apply(controller => controller.SetSceneMode(Scenes[index]))
                ).Header(T(language, "scene")),
                HStack(
                    12,
                    ComboBox(
                        ColorTemperatures.Select(value => Label(value, language)).ToArray(),
                        1,
                        index => apply(controller =>
                            controller.SetColorTemperature(ColorTemperatures[index]))
                    ).Header(T(language, "colorTemp")).Flex(grow: 1),
                    ComboBox(
                        VendorHdrModes.Select(value => Label(value, language)).ToArray(),
                        0,
                        index => apply(controller =>
                            controller.SetVendorHdr(VendorHdrModes[index]))
                    ).Header(T(language, "monitorHdr")).Flex(grow: 1)
                ),
                HStack(
                    12,
                    ComboBox(
                        LocalDimmingLevels.Select(value => Label(value, language)).ToArray(),
                        0,
                        index => apply(controller =>
                            controller.SetLocalDimming(LocalDimmingLevels[index]))
                    ).Header(T(language, "localDimming")).Flex(grow: 1),
                    ComboBox(
                        GammaLevels.Select(value => Label(value, language)).ToArray(),
                        2,
                        index => apply(controller =>
                            controller.SetOfficialGamma(GammaLevels[index]))
                    ).Header(T(language, "gamma")).Flex(grow: 1)
                )
            ),
            UiComponents.Card(
                T(language, "customScene"),
                T(language, "sceneDesc"),
                CustomSceneRange(language, state, TitanArmyProfile.CustomSceneTarget.Saturation, apply),
                CustomSceneRange(language, state, TitanArmyProfile.CustomSceneTarget.Gamma, apply),
                CustomSceneRange(language, state, TitanArmyProfile.CustomSceneTarget.Hue, apply),
                CustomSceneRange(language, state, TitanArmyProfile.CustomSceneTarget.NightVision, apply),
                CustomSceneRange(language, state, TitanArmyProfile.CustomSceneTarget.DynamicOverdrive, apply),
                CustomSceneRange(language, state, TitanArmyProfile.CustomSceneTarget.CrEnhance, apply),
                CustomSceneRange(language, state, TitanArmyProfile.CustomSceneTarget.ColorEnhance, apply)
            ),
            EnhancementCard(language, apply)
        );

    private static Element GamePage(
        string language,
        MonitorApplicationState state,
        PlatformCapabilities capabilities,
        Action<Action<MonitorController>> apply)
    {
        var crosshair = ReadingValue(state.Snapshot, "crosshair");
        var stopwatch = ReadingValue(state.Snapshot, "stopwatch");
        var gameTime = ReadingValue(state.Snapshot, "gameTime");
        var magnifier = ReadingValue(state.Snapshot, "magnifier");
        var hawkEye = ReadingValue(state.Snapshot, "hawkEye");

        return VStack(
            16,
            UiComponents.Card(
                T(language, "gameTitle"),
                T(language, "gameDesc"),
                HStack(
                    12,
                    ToggleSwitch(
                        crosshair,
                        enabled => apply(controller => controller.SetGameAssistant(
                            new TitanArmyProfile.GameAssistant.Command.CrosshairValue(
                                enabled.ToToggle()))),
                        header: T(language, "crosshair")
                    ).Flex(grow: 1),
                    ComboBox(
                        CrosshairShapes.Select(value => Label(value, language)).ToArray(),
                        0,
                        index => apply(controller => controller.SetGameAssistant(
                            new TitanArmyProfile.GameAssistant.Command.CrosshairShapeValue(
                                CrosshairShapes[index])))
                    ).Header(T(language, "crosshairShape")).Flex(grow: 1),
                    ComboBox(
                        CrosshairColors.Select(value => Label(value, language)).ToArray(),
                        0,
                        index => apply(controller => controller.SetGameAssistant(
                            new TitanArmyProfile.GameAssistant.Command.CrosshairColorValue(
                                CrosshairColors[index])))
                    ).Header(T(language, "crosshairColor")).Flex(grow: 1)
                ),
                HStack(
                    12,
                    ToggleSwitch(
                        stopwatch,
                        enabled => apply(controller => controller.SetGameAssistant(
                            new TitanArmyProfile.GameAssistant.Command.StopwatchValue(
                                enabled.ToToggle()))),
                        header: T(language, "stopwatch")
                    ).Flex(grow: 1),
                    ComboBox(
                        Durations.Select(value => Label(value, language)).ToArray(),
                        0,
                        index => apply(controller => controller.SetGameAssistant(
                            new TitanArmyProfile.GameAssistant.Command.StopwatchTimeValue(
                                Durations[index])))
                    ).Header(T(language, "stopwatchTime")).Flex(grow: 1),
                    ToggleSwitch(
                        gameTime,
                        enabled => apply(controller => controller.SetGameAssistant(
                            new TitanArmyProfile.GameAssistant.Command.GameTimeValue(
                                enabled.ToToggle()))),
                        header: T(language, "gameTime")
                    ).Flex(grow: 1),
                    ComboBox(
                        Durations.Select(value => Label(value, language)).ToArray(),
                        0,
                        index => apply(controller => controller.SetGameAssistant(
                            new TitanArmyProfile.GameAssistant.Command.GameTimeDurationValue(
                                Durations[index])))
                    ).Header(T(language, "gameTimeValue")).Flex(grow: 1)
                )
            ),
            UiComponents.Card(
                T(language, "magnifier"),
                T(language, "gameDesc"),
                HStack(
                    12,
                    ToggleSwitch(
                        magnifier,
                        enabled => apply(controller => controller.SetGameAssistant(
                            new TitanArmyProfile.GameAssistant.Command.MagnifierValue(
                                enabled.ToToggle()))),
                        header: T(language, "magnifier")
                    ).Flex(grow: 1),
                    ComboBox(
                        MagnifierSizes.Select(value => Label(value, language)).ToArray(),
                        1,
                        index => apply(controller => controller.SetGameAssistant(
                            new TitanArmyProfile.GameAssistant.Command.MagnifierSizeValue(
                                MagnifierSizes[index])))
                    ).Header(T(language, "magnifierSize")).Flex(grow: 1),
                    ComboBox(
                        Magnifications.Select(value => Label(value, language)).ToArray(),
                        2,
                        index => apply(controller => controller.SetGameAssistant(
                            new TitanArmyProfile.GameAssistant.Command.MagnificationValue(
                                Magnifications[index])))
                    ).Header(T(language, "magnification")).Flex(grow: 1),
                    ComboBox(
                        MagnifierPositions.Select(value => Label(value, language)).ToArray(),
                        0,
                        index => apply(controller => controller.SetGameAssistant(
                            new TitanArmyProfile.GameAssistant.Command.MagnifierPositionValue(
                                MagnifierPositions[index])))
                    ).Header(T(language, "magnifierPosition")).Flex(grow: 1)
                ),
                HStack(
                    12,
                    ToggleSwitch(
                        hawkEye,
                        enabled => apply(controller => controller.SetGameAssistant(
                            new TitanArmyProfile.GameAssistant.Command.HawkEyeValue(
                                enabled.ToToggle()))),
                        header: T(language, "hawkEye")
                    ).Flex(grow: 1),
                    ComboBox(
                        HawkEyeLevels.Select(value => Label(value, language)).ToArray(),
                        1,
                        index => apply(controller => controller.SetGameAssistant(
                            new TitanArmyProfile.GameAssistant.Command.HawkEyeLevelValue(
                                HawkEyeLevels[index])))
                    ).Header(T(language, "hawkEyeLevel")).Flex(grow: 1),
                    ComboBox(
                        Enum.GetValues<TitanArmyProfile.NightVisionLevel>()
                            .Select(value => Label(value, language)).ToArray(),
                        0,
                        index => apply(controller => controller.SetGameAssistant(
                            new TitanArmyProfile.GameAssistant.Command.NightVisionValue(
                                Enum.GetValues<TitanArmyProfile.NightVisionLevel>()[index])))
                    ).Header(T(language, "nightVision")).Flex(grow: 1)
                ),
                ToggleSwitch(
                    false,
                    enabled => apply(controller => controller.SetGameAssistant(
                        new TitanArmyProfile.GameAssistant.Command.AlignmentValue(
                            enabled.ToToggle()))),
                    header: T(language, "alignment")
                ),
                HStack(
                    12,
                    ComboBox(
                        ScreenSizes.Select(value => Label(value, language)).ToArray(),
                        0,
                        index => apply(controller => controller.SetGameAssistant(
                            new TitanArmyProfile.GameAssistant.Command.ScreenSizeValue(
                                ScreenSizes[index])))
                    ).Header(T(language, "screenSize")).Flex(grow: 1),
                    ComboBox(
                        RefreshPositions.Select(value => Label(value, language)).ToArray(),
                        0,
                        index => apply(controller => controller.SetGameAssistant(
                            new TitanArmyProfile.GameAssistant.Command.RefreshPositionValue(
                                RefreshPositions[index])))
                    ).Header(T(language, "refreshPosition")).Flex(grow: 1)
                ),
                capabilities.VendorHidAvailable
                    ? Empty()
                    : Caption(capabilities.VendorHidReason ?? T(language, "hidRequired"))
                        .Foreground(SecondaryText)
            ),
            UiComponents.Card(
                T(language, "basic"),
                T(language, "gameDesc"),
                HStack(
                    12,
                    ComboBox(
                        DynamicOverdriveLevels.Select(value => Label(value, language)).ToArray(),
                        0,
                        index => apply(controller =>
                            controller.SetDynamicOverdrive(DynamicOverdriveLevels[index]))
                    ).Header(T(language, "dynamicOd")).Flex(grow: 1),
                    ComboBox(
                        DyDsLevels.Select(value => Label(value, language)).ToArray(),
                        0,
                        index => apply(controller => controller.SetDyDsUll(DyDsLevels[index]))
                    ).Header(T(language, "dydsUll")).Flex(grow: 1),
                    ComboBox(
                        SharpnessLevels.Select(value => Label(value, language)).ToArray(),
                        2,
                        index => apply(controller => controller.SetSharpness(SharpnessLevels[index]))
                    ).Header(T(language, "sharpness")).Flex(grow: 1)
                ),
                HStack(
                    12,
                    ToggleSwitch(
                        false,
                        enabled => apply(controller => controller.SetGameRush(enabled)),
                        header: T(language, "gameRush")
                    ).Flex(grow: 1),
                    ToggleSwitch(
                        false,
                        enabled => apply(controller => controller.SetAdaptiveSync(enabled)),
                        header: T(language, "adaptiveSync")
                    ).Flex(grow: 1),
                    ComboBox(
                        LowBlueLevels.Select(value => Label(value, language)).ToArray(),
                        0,
                        index => apply(controller => controller.SetLowBlueLight(LowBlueLevels[index]))
                    ).Header(T(language, "lowBlueLight")).Flex(grow: 1)
                )
            )
        );
    }

    private static Element DarkPage(string language, PlatformCapabilities capabilities) =>
        VStack(
            16,
            UiComponents.Card(
                T(language, "darkTitle"),
                T(language, "darkDesc"),
                UiComponents.DisabledFeature("PrimalGlory / Matrix Lamp", T(language, "hidRequired")),
                UiComponents.DisabledFeature("Animate Mode / Text Mode / Music Mode",
                    T(language, "hidRequired")),
                UiComponents.DisabledFeature("Custom Animate", T(language, "hidRequired")),
                Caption(capabilities.VendorHidReason ?? T(language, "hidRequired"))
                    .Foreground(SecondaryText)
            ),
            UiComponents.Card(
                T(language, "diagnostics"),
                null,
                UiComponents.Bullet("DDC/CI: DXVA2"),
                UiComponents.Bullet($"Vendor HID: {(capabilities.VendorHidAvailable ? "ready" : "unavailable")}"),
                UiComponents.Bullet($"System HDR adapter: {(capabilities.SystemHdrAvailable ? "ready" : "not implemented")}")
            )
        );

    private static Element BasicPage(
        string language,
        MonitorApplicationState state,
        Action<Action<MonitorController>> apply)
    {
        var snapshot = state.Snapshot;
        return VStack(
            16,
            snapshot.BrightnessLockedByHdr
                ? UiComponents.StatusNotice(
                    $"{T(language, "monitorHdr")}: HDR - {T(language, "brightness")} / {T(language, "contrast")} locked",
                    error: false)
                : Empty(),
            UiComponents.Card(
                T(language, "basicTitle"),
                T(language, "basicDesc"),
                UiComponents.Range(
                    T(language, "brightness"),
                    snapshot.Brightness.Available ? snapshot.Brightness.Value : 100,
                    0,
                    100,
                    T(language, "apply"),
                    value => apply(controller => controller.SetBrightness(value)),
                    enabled: !snapshot.BrightnessLockedByHdr),
                UiComponents.Range(
                    T(language, "contrast"),
                    snapshot.Contrast.Available ? snapshot.Contrast.Value : 50,
                    0,
                    100,
                    T(language, "apply"),
                    value => apply(controller => controller.SetContrast(value)),
                    enabled: !snapshot.BrightnessLockedByHdr),
                UiComponents.Range(
                    T(language, "volume"),
                    snapshot.Volume.Available ? snapshot.Volume.Value : 50,
                    0,
                    100,
                    T(language, "apply"),
                    value => apply(controller => controller.SetVolume(value))),
                ToggleSwitch(
                    snapshot.Muted.Available && snapshot.Muted.Value != 0,
                    muted => apply(controller => controller.SetMuted(muted)),
                    header: T(language, "mute")
                )
            ),
            UiComponents.Card(
                T(language, "settings"),
                null,
                UiComponents.Range(
                    T(language, "gamma"),
                    snapshot.Gamma.Available ? snapshot.Gamma.Value : 6,
                    0,
                    Math.Max(snapshot.Gamma.Maximum, 12),
                    T(language, "apply"),
                    value => apply(controller => controller.SetGamma(value)),
                    enabled: !snapshot.BrightnessLockedByHdr),
                UiComponents.Range(
                    T(language, "red"),
                    Percent(snapshot.RedGain, 48),
                    0,
                    100,
                    T(language, "apply"),
                    value => apply(controller =>
                        controller.SetColorGain(MonitorController.ColorChannel.Red, value)),
                    enabled: !snapshot.BrightnessLockedByHdr),
                UiComponents.Range(
                    T(language, "green"),
                    Percent(snapshot.GreenGain, 50),
                    0,
                    100,
                    T(language, "apply"),
                    value => apply(controller =>
                        controller.SetColorGain(MonitorController.ColorChannel.Green, value)),
                    enabled: !snapshot.BrightnessLockedByHdr),
                UiComponents.Range(
                    T(language, "blue"),
                    Percent(snapshot.BlueGain, 49),
                    0,
                    100,
                    T(language, "apply"),
                    value => apply(controller =>
                        controller.SetColorGain(MonitorController.ColorChannel.Blue, value)),
                    enabled: !snapshot.BrightnessLockedByHdr)
            ),
            UiComponents.Card(
                T(language, "input"),
                null,
                Caption(snapshot.InputSource.Available
                    ? $"0x{snapshot.InputSource.Value:X2}"
                    : T(language, "notReported")).Foreground(SecondaryText),
                ComboBox(
                    OutputRanges.Select(value => Label(value, language)).ToArray(),
                    0,
                    index => apply(controller => controller.SetRgbOutputRange(OutputRanges[index]))
                ).Header(T(language, "outputRange")),
                ComboBox(
                    Enum.GetValues<TitanArmyProfile.Overdrive>()
                        .Select(value => Label(value, language)).ToArray(),
                    0,
                    index => apply(controller => controller.SetOverdrive(
                        Enum.GetValues<TitanArmyProfile.Overdrive>()[index]))
                ).Header(T(language, "overdrive"))
            )
        );
    }

    private static Element OledPage(
        string language,
        MonitorApplicationState state,
        Action<Action<MonitorController>> apply,
        PlatformCapabilities capabilities) =>
        VStack(
            16,
            UiComponents.Card(
                T(language, "oledTitle"),
                T(language, "oledDesc"),
                TextBlock(T(language, "usage")).SemiBold(),
                TextBlock(state.Snapshot.UsageTime.Available
                    ? $"{state.Snapshot.UsageTime.Value} min"
                    : T(language, "notReported")).Foreground(SecondaryText),
                ComboBox(
                    LocalDimmingLevels.Select(value => Label(value, language)).ToArray(),
                    0,
                    index => apply(controller => controller.SetLocalDimming(LocalDimmingLevels[index]))
                ).Header(T(language, "localDimming")),
                UiComponents.DisabledFeature("Pixel Refresh / OLED Protect",
                    "The register mapping has not been verified for this firmware. No unknown VCP is written.")
            ),
            UiComponents.Card(
                T(language, "diagnostics"),
                null,
                UiComponents.Bullet($"DDC/CI: {state.IsConnected}"),
                UiComponents.Bullet($"Vendor HID: {capabilities.VendorHidAvailable}"),
                UiComponents.Bullet($"Snapshot: {state.LastUpdated:yyyy-MM-dd HH:mm:ss}")
            )
        );

    private static Element SupportPage(string language, MonitorApplicationState state) =>
        VStack(
            16,
            UiComponents.Card(
                T(language, "supportTitle"),
                T(language, "supportDesc"),
                TextBlock(T(language, "device")).SemiBold(),
                Caption(state.Displays.FirstOrDefault(x => x.Id == state.SelectedDisplayId)?.Label
                        ?? T(language, "noDisplay"))
                    .Foreground(SecondaryText),
                HStack(
                    12,
                    Button(T(language, "officialSupport"), () =>
                            OpenUrl("https://www.titanarmy.cn/support/"))
                        .AutomationName(T(language, "officialSupport")),
                    Button(T(language, "downloadCenter"), () =>
                            OpenUrl("https://titan-army.com/pages/download-center"))
                        .AutomationName(T(language, "downloadCenter"))
                )
            ),
            UiComponents.Card(
                T(language, "diagnostics"),
                null,
                DiagnosticLine("Brightness", state.Snapshot.Brightness, language),
                DiagnosticLine("Contrast", state.Snapshot.Contrast, language),
                DiagnosticLine("Volume", state.Snapshot.Volume, language),
                DiagnosticLine("Gamma", state.Snapshot.Gamma, language),
                DiagnosticLine("Input", state.Snapshot.InputSource, language),
                DiagnosticLine("Usage", state.Snapshot.UsageTime, language),
                DiagnosticLine("Overdrive", state.Snapshot.Overdrive, language),
                DiagnosticLine("Vendor HDR", state.Snapshot.VendorHdr, language)
            )
        );

    private static Element StorePage(string language) =>
        VStack(
            18,
            UiComponents.Card(
                T(language, "storeTitle"),
                T(language, "storeDesc"),
                TextBlock("P275MV PLUS").FontSize(32).Bold().Foreground(Accent),
                TextBlock("TITAN ARMY").FontSize(16).SemiBold().Foreground(SecondaryText),
                HStack(
                    12,
                    Button(T(language, "officialStore"), () =>
                            OpenUrl("https://www.titanarmy.cn/"))
                        .AutomationName(T(language, "officialStore")),
                    Button(T(language, "downloadCenter"), () =>
                            OpenUrl("https://titan-army.com/pages/download-center"))
                        .AutomationName(T(language, "downloadCenter"))
                )
            ),
            UiComponents.Card(
                T(language, "supportTitle"),
                T(language, "storeDesc"),
                UiComponents.Bullet("P275MV PLUS driver and utility downloads"),
                UiComponents.Bullet("Warranty and customer support"),
                UiComponents.Bullet("Firmware and documentation")
            )
        );

    private static Element EnhancementCard(
        string language,
        Action<Action<MonitorController>> apply) =>
        UiComponents.Card(
            T(language, "settings"),
            "Color Enhance 0-10 · CR 0-5 · Shadow/HL 0-100",
            EnhancementRange(language, TitanArmyProfile.Enhancement.ColorEnhance, 0, 10, apply),
            EnhancementRange(language, TitanArmyProfile.Enhancement.CrEnhance, 0, 5, apply),
            EnhancementRange(language, TitanArmyProfile.Enhancement.ShadowBalance, 0, 100, apply),
            EnhancementRange(language, TitanArmyProfile.Enhancement.SuperResolution, 0, 5, apply),
            EnhancementRange(language, TitanArmyProfile.Enhancement.HaloControl, 0, 100, apply)
        );

    private static Element EnhancementRange(
        string language,
        TitanArmyProfile.Enhancement enhancement,
        int minimum,
        int maximum,
        Action<Action<MonitorController>> apply) =>
        UiComponents.Range(
            T(language, enhancement switch
            {
                TitanArmyProfile.Enhancement.ColorEnhance => "colorEnhance",
                TitanArmyProfile.Enhancement.CrEnhance => "crEnhance",
                TitanArmyProfile.Enhancement.ShadowBalance => "shadowBalance",
                TitanArmyProfile.Enhancement.SuperResolution => "superResolution",
                TitanArmyProfile.Enhancement.HaloControl => "haloControl",
                _ => "settings",
            }),
            minimum,
            minimum,
            maximum,
            T(language, "apply"),
            value => apply(controller => controller.SetEnhancement(enhancement, value)));

    private static Element CustomSceneRange(
        string language,
        MonitorApplicationState state,
        TitanArmyProfile.CustomSceneTarget target,
        Action<Action<MonitorController>> apply)
    {
        var range = target.Setting().AllowedRange();
        return UiComponents.Range(
            CustomSceneLabel(target, language),
            range.Minimum,
            range.Minimum,
            range.Maximum,
            T(language, "apply"),
            value => apply(controller => controller.SetCustomScene(target, value)));
    }

    private static Element DiagnosticLine(
        string label,
        DisplayReading reading,
        string language) =>
        HStack(
            12,
            TextBlock(label).Width(120).Foreground(SecondaryText),
            TextBlock(reading.Available
                    ? $"{reading.Value} / {reading.Maximum}"
                    : reading.Error ?? T(language, "notReported"))
                .Foreground(reading.Available ? PrimaryText : SecondaryText)
                .Flex(grow: 1)
        );

    private static bool ReadingValue(DisplaySnapshot snapshot, string key) => key switch
    {
        _ => false,
    };

    private static int Percent(DisplayReading reading, int fallback) =>
        reading.Available && reading.Maximum > 0
            ? (int)Math.Round(reading.Value * 100d / reading.Maximum)
            : fallback;

    private static int IndexOf<T>(IReadOnlyList<T> values, T value) where T : struct, Enum
    {
        for (var index = 0; index < values.Count; index++)
        {
            if (EqualityComparer<T>.Default.Equals(values[index], value))
            {
                return index;
            }
        }

        return 0;
    }

    private static string SceneLabel(TitanArmyProfile.SceneMode mode, string language) =>
        (language, mode) switch
        {
            ("zh", TitanArmyProfile.SceneMode.Standard) => "标准",
            ("zh", TitanArmyProfile.SceneMode.RtsRpg) => "RTS / RPG",
            ("zh", TitanArmyProfile.SceneMode.Movie) => "电影",
            ("zh", TitanArmyProfile.SceneMode.Reading) => "阅读",
            ("zh", TitanArmyProfile.SceneMode.Night) => "夜间",
            ("zh", TitanArmyProfile.SceneMode.EyeCare) => "护眼",
            ("zh", TitanArmyProfile.SceneMode.MacView) => "Mac 视图",
            ("zh", TitanArmyProfile.SceneMode.EBook) => "电子书",
            ("zh", TitanArmyProfile.SceneMode.DyDsUllFps) => "DyDs / ULL FPS",
            ("zh", TitanArmyProfile.SceneMode.DyDsLocalDimming) => "DyDs / 分区调光",
            ("zh", TitanArmyProfile.SceneMode.Custom) => "自定义",
            _ => mode.ToString(),
        };

    private static string Label<T>(T value, string language) where T : struct, Enum
    {
        var raw = value.ToString();
        if (language != "zh")
        {
            return (object)value switch
            {
                TitanArmyProfile.LocalDimming.Off => "Off",
                TitanArmyProfile.LocalDimming.Smooth => "Smooth",
                TitanArmyProfile.DynamicOverdriveLevel.Topspeed => "Topspeed",
                TitanArmyProfile.VendorHdr.Auto => "Auto",
                _ => raw,
            };
        }

        return (object)value switch
        {
            TitanArmyProfile.ColorTemperature.Warm => "暖色",
            TitanArmyProfile.ColorTemperature.Natural => "自然",
            TitanArmyProfile.ColorTemperature.Cold => "冷色",
            TitanArmyProfile.ColorTemperature.User1 => "用户 1",
            TitanArmyProfile.ColorTemperature.User2 => "用户 2",
            TitanArmyProfile.ColorTemperature.User3 => "用户 3",
            TitanArmyProfile.VendorHdr.Off => "关闭",
            TitanArmyProfile.VendorHdr.Auto => "自动",
            TitanArmyProfile.VendorHdr.Game => "游戏",
            TitanArmyProfile.VendorHdr.Movie => "电影",
            TitanArmyProfile.LocalDimming.Off => "关闭",
            TitanArmyProfile.LocalDimming.Low => "低",
            TitanArmyProfile.LocalDimming.Smooth => "平滑",
            TitanArmyProfile.LocalDimming.Medium => "中",
            TitanArmyProfile.LocalDimming.High => "高",
            TitanArmyProfile.Overdrive.Off => "关闭",
            TitanArmyProfile.Overdrive.Normal => "普通",
            TitanArmyProfile.Overdrive.Fast => "快速",
            TitanArmyProfile.Overdrive.Fastest => "最快",
            TitanArmyProfile.OfficialGamma.SCurve => "S 曲线",
            TitanArmyProfile.DynamicOverdriveLevel.Topspeed => "极速",
            TitanArmyProfile.DyDsUllLevel.Off => "关闭",
            TitanArmyProfile.LowBlueLightLevel.Off => "关闭",
            TitanArmyProfile.SharpnessLevel.Off => "关闭",
            TitanArmyProfile.RgbOutputRange.Auto => "自动",
            TitanArmyProfile.RgbOutputRange.Limited => "限制",
            TitanArmyProfile.RgbOutputRange.Full => "完整",
            TitanArmyProfile.GameAssistant.CrosshairColor.Red => "红色",
            TitanArmyProfile.GameAssistant.CrosshairColor.Yellow => "黄色",
            TitanArmyProfile.GameAssistant.CrosshairColor.Green => "绿色",
            TitanArmyProfile.GameAssistant.CrosshairColor.Cyan => "青色",
            TitanArmyProfile.GameAssistant.CrosshairColor.Blue => "蓝色",
            TitanArmyProfile.GameAssistant.CrosshairColor.Purple => "紫色",
            TitanArmyProfile.GameAssistant.CrosshairColor.White => "白色",
            TitanArmyProfile.GameAssistant.CrosshairColor.Automatic => "自动",
            TitanArmyProfile.GameAssistant.MagnifierSize.Small => "小",
            TitanArmyProfile.GameAssistant.MagnifierSize.Medium => "中",
            TitanArmyProfile.GameAssistant.MagnifierSize.Large => "大",
            TitanArmyProfile.GameAssistant.MagnifierPosition.TopRight => "右上",
            TitanArmyProfile.GameAssistant.MagnifierPosition.TopLeft => "左上",
            TitanArmyProfile.GameAssistant.MagnifierPosition.BottomRight => "右下",
            TitanArmyProfile.GameAssistant.MagnifierPosition.BottomLeft => "左下",
            TitanArmyProfile.GameAssistant.MagnifierPosition.Central => "中央",
            TitanArmyProfile.NightVisionLevel.Off => "关闭",
            TitanArmyProfile.NightVisionLevel.AutoLevel1 => "自动 1",
            TitanArmyProfile.NightVisionLevel.AutoLevel2 => "自动 2",
            _ => raw.Replace("Level", "等级 ").Replace("Minutes", "").Replace("Inch", "英寸 "),
        };
    }

    private static string CustomSceneLabel(
        TitanArmyProfile.CustomSceneTarget target,
        string language) =>
        (language, target) switch
        {
            ("zh", TitanArmyProfile.CustomSceneTarget.Saturation) => "饱和度",
            ("zh", TitanArmyProfile.CustomSceneTarget.Gamma) => "Gamma",
            ("zh", TitanArmyProfile.CustomSceneTarget.Hue) => "色相",
            ("zh", TitanArmyProfile.CustomSceneTarget.NightVision) => "夜视",
            ("zh", TitanArmyProfile.CustomSceneTarget.DynamicOverdrive) => "动态 OD",
            ("zh", TitanArmyProfile.CustomSceneTarget.CrEnhance) => "对比增强",
            ("zh", TitanArmyProfile.CustomSceneTarget.ColorEnhance) => "色彩增强",
            _ => target.ToString(),
        };

    private static string T(string language, string key) => Strings.Get(language, key);

    internal static void OpenUrl(string url) =>
        Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
}
