using TitanArmyControl.Core.Controller;
using TitanArmyControl.Core.Ddc;
using TitanArmyControl.Core.Model;
using TitanArmyControl.Core.Protocol;

namespace TitanArmyControl.Core.Tests;

public sealed class MonitorControllerTests
{
    [Fact]
    public void ToneWriteScalesToDisplayMaximum()
    {
        var transport = new FakeTransport();
        var controller = Controller(transport);

        controller.SetBrightness(30);

        Assert.Equal(30, transport.Values[VcpCode.Brightness]);
    }

    [Fact]
    public void ToneWriteFailsBeforeTransportWhenHdrIsOn()
    {
        var transport = new FakeTransport();
        var controller = new MonitorController(
            Descriptor(),
            new DdcSession(transport),
            new FakeHdrControl(true));

        var error = Assert.Throws<InvalidOperationException>(() => controller.SetContrast(40));

        Assert.Contains("HDR", error.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Empty(transport.Writes);
    }

    [Fact]
    public void VendorCommandUsesSelectorThenTargetAndSkipsDuplicate()
    {
        var transport = new FakeTransport();
        var controller = Controller(transport);

        controller.SetSceneMode(TitanArmyProfile.SceneMode.Fps);
        controller.SetSceneMode(TitanArmyProfile.SceneMode.Fps);

        Assert.Equal(
            [
                (VcpCode.Vendor.Selector, (ushort)TitanArmyProfile.SceneMode.Fps),
                (VcpCode.Vendor.SceneMode, (ushort)TitanArmyProfile.SceneMode.Fps),
            ],
            transport.Writes);
    }

    [Fact]
    public void MutuallyExclusiveOverlayIsCleared()
    {
        var transport = new FakeTransport();
        var controller = Controller(transport);

        controller.SetGameAssistant(
            new TitanArmyProfile.GameAssistant.Command.CrosshairValue(TitanArmyProfile.Toggle.On));

        Assert.Contains((VcpCode.Vendor.Selector, (ushort)0), transport.Writes);
        Assert.Contains((VcpCode.Vendor.GameAssistantStopwatchEnable, (ushort)0), transport.Writes);
        Assert.Contains((VcpCode.Vendor.GameAssistantGameTimeEnable, (ushort)0), transport.Writes);
    }

    private static MonitorController Controller(FakeTransport transport) =>
        new(Descriptor(), new DdcSession(transport), new FakeHdrControl(false));

    private static DisplayDescriptor Descriptor() =>
        new("fake", "P275MV PLUS", "LHC", 0x907D, true, false, "fake");

    private sealed class FakeHdrControl(bool enabled) : ISystemHdrControl
    {
        public TimeSpan PostSwitchSettleDelay => TimeSpan.Zero;
        public bool? IsEnabled(DisplayDescriptor descriptor) => enabled;
        public bool SetEnabled(bool value, DisplayDescriptor descriptor) => value == enabled;
    }
}
