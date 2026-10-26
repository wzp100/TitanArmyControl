using System.Text;
using System.Runtime.InteropServices;
using TitanArmyControl.Core.Controller;
using TitanArmyControl.Core.Ddc;
using TitanArmyControl.Core.Model;

namespace TitanArmyControl.Platform.Windows;

public sealed class WindowsDisplayCatalog : IDisplayCatalog, IPlatformCapabilitiesProvider
{
    public PlatformCapabilities Capabilities { get; } = new(
        DdcAvailable: true,
        VendorHidAvailable: false,
        SystemHdrAvailable: false,
        VendorHidReason:
            "Dark Oracle lighting, animation, and text controls require the monitor USB data channel and a verified vendor HID protocol.");

    public IReadOnlyList<DisplayDescriptor> Discover() =>
        Enumerate().Select(x => x.Descriptor).ToArray();

    public IMonitorConnection? Connect(DisplayDescriptor descriptor)
    {
        var monitor = Enumerate().FirstOrDefault(x => x.Descriptor.Id == descriptor.Id);
        if (monitor is null)
        {
            return null;
        }

        var transport = new Dxva2DdcTransport(monitor.Handle, monitor.Descriptor.TransportHint);
        var controller = new MonitorController(
            monitor.Descriptor,
            new DdcSession(transport),
            new UnavailableSystemHdrControl());
        return new WindowsMonitorConnection(monitor.Descriptor, controller);
    }

    private static List<DiscoveredMonitor> Enumerate()
    {
        var result = new List<DiscoveredMonitor>();
        NativeMethods.EnumDisplayMonitors(
            IntPtr.Zero,
            IntPtr.Zero,
            (monitor, _, _, _) =>
            {
                AddPhysicalMonitors(monitor, result);
                return true;
            },
            IntPtr.Zero);
        return result;
    }

    private static void AddPhysicalMonitors(IntPtr logicalMonitor, List<DiscoveredMonitor> result)
    {
        var info = new NativeMethods.MonitorInfoEx
        {
            Size = Marshal.SizeOf<NativeMethods.MonitorInfoEx>(),
            DeviceName = string.Empty,
        };
        if (!NativeMethods.GetMonitorInfo(logicalMonitor, ref info))
        {
            return;
        }

        if (!NativeMethods.GetNumberOfPhysicalMonitorsFromHMONITOR(logicalMonitor, out var count) ||
            count == 0)
        {
            return;
        }

        var monitors = new NativeMethods.PhysicalMonitor[count];
        if (!NativeMethods.GetPhysicalMonitorsFromHMONITOR(logicalMonitor, count, monitors))
        {
            return;
        }

        foreach (var physical in monitors)
        {
            var description = ReadDescription(physical);
            var id = string.Join(
                "|",
                info.DeviceName,
                info.Monitor.Left,
                info.Monitor.Top,
                info.Monitor.Right,
                info.Monitor.Bottom,
                description);
            var isTarget =
                description.Contains("P275MV", StringComparison.OrdinalIgnoreCase) ||
                description.Contains("TITAN ARMY", StringComparison.OrdinalIgnoreCase) ||
                description.Contains("LHC", StringComparison.OrdinalIgnoreCase);
            var descriptor = new DisplayDescriptor(
                id,
                string.IsNullOrWhiteSpace(description) ? info.DeviceName : description,
                isTarget ? "LHC" : null,
                isTarget ? (ushort)0x907D : null,
                isTarget,
                IsBuiltIn: false,
                TransportHint: $"DXVA2:{info.DeviceName}");
            result.Add(new DiscoveredMonitor(descriptor, physical.Handle));
        }
    }

    private static string ReadDescription(NativeMethods.PhysicalMonitor monitor)
    {
        if (!string.IsNullOrWhiteSpace(monitor.Description))
        {
            return monitor.Description.Trim();
        }

        var buffer = new StringBuilder(128);
        return NativeMethods.GetPhysicalMonitorDescription(monitor.Handle, (uint)buffer.Capacity, buffer)
            ? buffer.ToString().Trim()
            : string.Empty;
    }

    private sealed record DiscoveredMonitor(DisplayDescriptor Descriptor, IntPtr Handle);

    private sealed class WindowsMonitorConnection : IMonitorConnection
    {
        private readonly MonitorController _controller;

        public WindowsMonitorConnection(
            DisplayDescriptor descriptor,
            MonitorController controller)
        {
            Descriptor = descriptor;
            _controller = controller;
        }

        public DisplayDescriptor Descriptor { get; }
        public MonitorController Controller => _controller;

        public void Dispose()
        {
            _controller.Session.Transport.Dispose();
        }
    }
}
