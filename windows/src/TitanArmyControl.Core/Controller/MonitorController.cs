using TitanArmyControl.Core.Ddc;
using TitanArmyControl.Core.Model;
using TitanArmyControl.Core.Protocol;

namespace TitanArmyControl.Core.Controller;

public sealed class MonitorController
{
    private readonly object _vendorCacheGate = new();
    private readonly Dictionary<byte, ushort> _lastOfficialValue = [];
    private readonly ISystemHdrControl _hdrControl;

    public MonitorController(
        DisplayDescriptor descriptor,
        DdcSession session,
        ISystemHdrControl? hdrControl = null)
    {
        Descriptor = descriptor;
        Session = session;
        _hdrControl = hdrControl ?? new UnavailableSystemHdrControl();
    }

    public DisplayDescriptor Descriptor { get; }
    public DdcSession Session { get; }
    public bool? HdrEnabled => _hdrControl.IsEnabled(Descriptor);

    public DisplaySnapshot Snapshot(bool thorough = false) =>
        DisplaySnapshot.Read(Session, HdrEnabled, thorough);

    public VcpReply SetBrightness(int percent) => SetTone(VcpCode.Brightness, percent);
    public VcpReply SetContrast(int percent) => SetTone(VcpCode.Contrast, percent);

    public VcpReply SetVolume(int percent)
    {
        var clamped = Math.Clamp(percent, 0, 100);
        var reply = Session.Read(VcpCode.Volume);
        var target = (ushort)Math.Round(clamped / 100d * reply.Maximum);
        return target == reply.Current ? reply : Session.Write(VcpCode.Volume, target);
    }

    public VcpReply SetMuted(bool muted) =>
        Session.Write(VcpCode.Mute, muted ? (ushort)1 : (ushort)0);

    public VcpReply SetGamma(int value)
    {
        EnsureToneUnlocked();
        var reply = Session.Read(VcpCode.Gamma);
        if (value < 0 || value > reply.Maximum)
        {
            throw new ArgumentOutOfRangeException(
                nameof(value), value, $"Gamma must be between 0 and {reply.Maximum}.");
        }

        return Session.Write(VcpCode.Gamma, (ushort)value);
    }

    public VcpReply SetColorGain(ColorChannel channel, int percent)
    {
        EnsureToneUnlocked();
        var clamped = Math.Clamp(percent, 0, 100);
        var reply = Session.Read(channel.Vcp());
        var value = (ushort)Math.Round(clamped / 100d * reply.Maximum);
        return Session.Write(channel.Vcp(), value);
    }

    public VcpReply SetInputSource(ushort input)
    {
        var reply = Session.Read(VcpCode.InputSource);
        if (input > reply.Maximum)
        {
            throw new ArgumentOutOfRangeException(
                nameof(input), input, $"Input value must not exceed {reply.Maximum}.");
        }

        return Session.Write(VcpCode.InputSource, input);
    }

    public bool SetSystemHdr(bool enabled)
    {
        var changed = HdrEnabled != enabled;
        var confirmed = _hdrControl.SetEnabled(enabled, Descriptor);
        if (changed)
        {
            Thread.Sleep(_hdrControl.PostSwitchSettleDelay);
        }

        return confirmed || HdrEnabled == enabled;
    }

    public void SetVendorHdr(TitanArmyProfile.VendorHdr mode) =>
        SendOfficial(TitanArmyProfile.WindowsSetting.HdrMode, (ushort)mode);

    public void SetLocalDimming(TitanArmyProfile.LocalDimming level) =>
        SendOfficial(TitanArmyProfile.WindowsSetting.LocalDimming, (ushort)level);

    public void SetSceneMode(TitanArmyProfile.SceneMode mode) =>
        SendOfficial(TitanArmyProfile.WindowsSetting.SceneMode, (ushort)mode);

    public void SetColorTemperature(TitanArmyProfile.ColorTemperature temperature) =>
        SendOfficial(TitanArmyProfile.WindowsSetting.ColorTemperature, (ushort)temperature);

    public void SetNightVision(TitanArmyProfile.NightVisionLevel level) =>
        SendOfficial(TitanArmyProfile.WindowsSetting.NightVision, (ushort)level);

    public void SetDynamicOverdrive(TitanArmyProfile.DynamicOverdriveLevel level) =>
        SendOfficial(TitanArmyProfile.WindowsSetting.DynamicOverdrive, (ushort)level);

    public void SetDyDsUll(TitanArmyProfile.DyDsUllLevel level) =>
        SendOfficial(TitanArmyProfile.WindowsSetting.DyDsUll, (ushort)level);

    public void SetSharpness(TitanArmyProfile.SharpnessLevel level) =>
        SendOfficial(TitanArmyProfile.WindowsSetting.Sharpness, (ushort)level);

    public void SetLowBlueLight(TitanArmyProfile.LowBlueLightLevel level) =>
        SendOfficial(TitanArmyProfile.WindowsSetting.LowBlueLight, (ushort)level);

    public void SetAdaptiveSync(bool enabled) =>
        SendOfficial(TitanArmyProfile.WindowsSetting.AdaptiveSync, (ushort)enabled.ToToggle());

    public void SetOfficialGamma(TitanArmyProfile.OfficialGamma gamma) =>
        SendOfficial(TitanArmyProfile.WindowsSetting.Gamma, (ushort)gamma);

    public void SetGameRush(bool enabled) =>
        SendOfficial(TitanArmyProfile.WindowsSetting.GameRush, (ushort)enabled.ToToggle());

    public void SetEnhancement(TitanArmyProfile.Enhancement enhancement, int value)
    {
        var setting = enhancement.Setting();
        SendOfficial(setting, CheckedValue(value, setting));
    }

    public void SetRgbOutputRange(TitanArmyProfile.RgbOutputRange range) =>
        SendOfficial(TitanArmyProfile.WindowsSetting.RgbOutputRange, (ushort)range);

    public void SetCustomScene(TitanArmyProfile.CustomSceneTarget target, int value)
    {
        var setting = target.Setting();
        var checkedValue = CheckedValue(value, setting);
        SendOfficial(TitanArmyProfile.WindowsSetting.SceneMode, (ushort)TitanArmyProfile.SceneMode.Custom);
        SendOfficial(setting, checkedValue);
    }

    public void SetGameAssistant(TitanArmyProfile.GameAssistant.Command command) =>
        SendOfficial(command.Setting, command.Value, command.ClearedOverlays);

    public VcpReply SetOverdrive(TitanArmyProfile.Overdrive level) =>
        Session.Write(VcpCode.Vendor.Overdrive, (ushort)level);

    public VcpReply WriteVendorValue(byte vcp, ushort value)
    {
        var register = TitanArmyProfile.Register(vcp)
            ?? throw new InvalidOperationException($"Unknown VCP 0x{vcp:X2}; write refused.");
        if (register.Certainty == TitanArmyProfile.Certainty.Refuted)
        {
            throw new InvalidOperationException($"VCP 0x{vcp:X2} is refuted; write refused.");
        }

        return Session.Write(vcp, value);
    }

    public void ResetVendorStateCache()
    {
        lock (_vendorCacheGate)
        {
            _lastOfficialValue.Clear();
        }
    }

    private VcpReply SetTone(byte vcp, int percent)
    {
        EnsureToneUnlocked();
        var clamped = Math.Clamp(percent, 0, 100);
        var reply = Session.Read(vcp);
        var scaled = (ushort)Math.Round(clamped / 100d * reply.Maximum);
        return Session.Write(vcp, scaled);
    }

    private void SendOfficial(
        TitanArmyProfile.WindowsSetting setting,
        ushort value,
        IReadOnlyList<TitanArmyProfile.WindowsSetting>? clearing = null)
    {
        lock (_vendorCacheGate)
        {
            if (_lastOfficialValue.TryGetValue(setting.Register(), out var previous) && previous == value)
            {
                return;
            }
        }

        WriteOfficialPair(setting, value);
        foreach (var overlay in clearing ?? [])
        {
            WriteOfficialPair(overlay, 0);
        }

        lock (_vendorCacheGate)
        {
            _lastOfficialValue[setting.Register()] = value;
            foreach (var overlay in clearing ?? [])
            {
                _lastOfficialValue.Remove(overlay.Register());
            }
        }

        Thread.Sleep(setting.SettleDelay());
    }

    private void WriteOfficialPair(TitanArmyProfile.WindowsSetting setting, ushort value)
    {
        try
        {
            Session.WriteVendorPair(setting, value, TimeSpan.FromMilliseconds(220));
        }
        catch (DdcException error)
        {
            throw new DdcException(
                $"Vendor command failed for target 0x{setting.Register():X2}.", error);
        }
    }

    private static ushort CheckedValue(int value, TitanArmyProfile.WindowsSetting setting)
    {
        var range = setting.AllowedRange();
        if (!range.Contains(value))
        {
            throw new ArgumentOutOfRangeException(
                nameof(value), value,
                $"{setting} accepts {range.Minimum} through {range.Maximum}.");
        }

        return (ushort)value;
    }

    private void EnsureToneUnlocked()
    {
        if (HdrEnabled == true)
        {
            throw new InvalidOperationException(
                "HDR is on. Brightness and contrast are locked by the monitor while HDR is active.");
        }
    }

    public enum ColorChannel
    {
        Red,
        Green,
        Blue,
    }
}

public static class ColorChannelExtensions
{
    public static byte Vcp(this MonitorController.ColorChannel channel) => channel switch
    {
        MonitorController.ColorChannel.Red => VcpCode.RedGain,
        MonitorController.ColorChannel.Green => VcpCode.GreenGain,
        MonitorController.ColorChannel.Blue => VcpCode.BlueGain,
        _ => throw new ArgumentOutOfRangeException(nameof(channel)),
    };
}
