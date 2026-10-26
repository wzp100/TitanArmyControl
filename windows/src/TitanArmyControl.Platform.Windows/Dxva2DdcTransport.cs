using System.ComponentModel;
using System.Runtime.InteropServices;
using TitanArmyControl.Core.Ddc;

namespace TitanArmyControl.Platform.Windows;

internal sealed class Dxva2DdcTransport : IDdcTransport
{
    private IntPtr _handle;

    public Dxva2DdcTransport(IntPtr handle, string endpoint)
    {
        _handle = handle;
        Endpoint = endpoint;
    }

    public string Endpoint { get; }

    public DdcTransportReply Read(byte vcp)
    {
        ObjectDisposedException.ThrowIf(_handle == IntPtr.Zero, this);
        if (!NativeMethods.GetVCPFeatureAndVCPFeatureReply(
                _handle, vcp, out _, out var current, out var maximum))
        {
            var error = Marshal.GetLastWin32Error();
            return new DdcTransportReply(
                false, 0, 0, new Win32Exception(error).Message, Unsupported: error == 31);
        }

        return new DdcTransportReply(
            true,
            checked((ushort)Math.Min(current, ushort.MaxValue)),
            checked((ushort)Math.Min(maximum, ushort.MaxValue)),
            null);
    }

    public bool Write(byte vcp, ushort value)
    {
        ObjectDisposedException.ThrowIf(_handle == IntPtr.Zero, this);
        return NativeMethods.SetVCPFeature(_handle, vcp, value);
    }

    public void Dispose()
    {
        if (_handle == IntPtr.Zero)
        {
            return;
        }

        NativeMethods.DestroyPhysicalMonitor(_handle);
        _handle = IntPtr.Zero;
    }
}
