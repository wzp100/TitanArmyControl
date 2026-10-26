namespace TitanArmyControl.Core.Model;

public sealed record DisplayDescriptor(
    string Id,
    string Label,
    string? Vendor,
    ushort? ProductId,
    bool IsTargetModel,
    bool IsBuiltIn,
    string TransportHint)
{
    public bool IsExternal => !IsBuiltIn;
}

public interface IDisplayCatalog
{
    IReadOnlyList<DisplayDescriptor> Discover();
    IMonitorConnection? Connect(DisplayDescriptor descriptor);
}

public interface IMonitorConnection : IDisposable
{
    DisplayDescriptor Descriptor { get; }
    TitanArmyControl.Core.Controller.MonitorController Controller { get; }
}

public interface ISystemHdrControl
{
    bool? IsEnabled(DisplayDescriptor descriptor);
    bool SetEnabled(bool enabled, DisplayDescriptor descriptor);
    TimeSpan PostSwitchSettleDelay { get; }
}

public sealed class UnavailableSystemHdrControl : ISystemHdrControl
{
    public TimeSpan PostSwitchSettleDelay { get; } = TimeSpan.Zero;
    public bool? IsEnabled(DisplayDescriptor descriptor) => null;
    public bool SetEnabled(bool enabled, DisplayDescriptor descriptor) => false;
}

public sealed record PlatformCapabilities(
    bool DdcAvailable,
    bool VendorHidAvailable,
    bool SystemHdrAvailable,
    string? VendorHidReason);

public interface IPlatformCapabilitiesProvider
{
    PlatformCapabilities Capabilities { get; }
}
