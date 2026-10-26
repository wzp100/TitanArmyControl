using TitanArmyControl.Core.Ddc;
using TitanArmyControl.Core.Protocol;

namespace TitanArmyControl.Core.Controller;

public readonly record struct DisplayReading(
    int Value,
    int Maximum,
    bool Available,
    string? Error)
{
    public double Fraction => Maximum > 0
        ? Math.Clamp((double)Value / Maximum, 0d, 1d)
        : 0d;

    public static DisplayReading Unavailable { get; } = new(0, 0, false, null);

    public static DisplayReading From(VcpReply reply) =>
        new(reply.Current, Math.Max((int)reply.Maximum, 1), true, null);

    public static DisplayReading Failed(Exception error) =>
        new(0, 0, false, error.Message);
}

public sealed record DisplaySnapshot
{
    public DisplayReading Brightness { get; init; } = DisplayReading.Unavailable;
    public DisplayReading Contrast { get; init; } = DisplayReading.Unavailable;
    public DisplayReading Gamma { get; init; } = DisplayReading.Unavailable;
    public DisplayReading RedGain { get; init; } = DisplayReading.Unavailable;
    public DisplayReading GreenGain { get; init; } = DisplayReading.Unavailable;
    public DisplayReading BlueGain { get; init; } = DisplayReading.Unavailable;
    public DisplayReading Volume { get; init; } = DisplayReading.Unavailable;
    public DisplayReading Muted { get; init; } = DisplayReading.Unavailable;
    public DisplayReading InputSource { get; init; } = DisplayReading.Unavailable;
    public DisplayReading UsageTime { get; init; } = DisplayReading.Unavailable;
    public DisplayReading PictureMode { get; init; } = DisplayReading.Unavailable;
    public DisplayReading Overdrive { get; init; } = DisplayReading.Unavailable;
    public DisplayReading ScreenMode { get; init; } = DisplayReading.Unavailable;
    public DisplayReading VendorHdr { get; init; } = DisplayReading.Unavailable;
    public bool? HdrEnabled { get; init; }
    public bool BrightnessLockedByHdr => HdrEnabled == true;
    public DateTimeOffset Timestamp { get; init; } = DateTimeOffset.Now;

    public static DisplaySnapshot Read(DdcSession session, bool? hdrEnabled, bool thorough = false)
    {
        static DisplayReading ReadOne(DdcSession currentSession, byte vcp)
        {
            try
            {
                return DisplayReading.From(currentSession.Read(vcp));
            }
            catch (Exception error)
            {
                return DisplayReading.Failed(error);
            }
        }

        var snapshot = new DisplaySnapshot
        {
            HdrEnabled = hdrEnabled,
            Brightness = ReadOne(session, VcpCode.Brightness),
            Contrast = ReadOne(session, VcpCode.Contrast),
            Volume = ReadOne(session, VcpCode.Volume),
            Muted = ReadOne(session, VcpCode.Mute),
        };

        if (!thorough)
        {
            return snapshot;
        }

        return snapshot with
        {
            Gamma = ReadOne(session, VcpCode.Gamma),
            RedGain = ReadOne(session, VcpCode.RedGain),
            GreenGain = ReadOne(session, VcpCode.GreenGain),
            BlueGain = ReadOne(session, VcpCode.BlueGain),
            InputSource = ReadOne(session, VcpCode.InputSource),
            UsageTime = ReadOne(session, VcpCode.DisplayUsageTime),
            PictureMode = ReadOne(session, VcpCode.Vendor.PictureMode),
            Overdrive = ReadOne(session, VcpCode.Vendor.Overdrive),
            ScreenMode = ReadOne(session, VcpCode.Vendor.ScreenMode),
            VendorHdr = ReadOne(session, VcpCode.Vendor.HdrMode),
        };
    }
}
