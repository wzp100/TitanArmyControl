using System.Text.Json;
using TitanArmyControl.Core.Ddc;
using TitanArmyControl.Core.Protocol;

namespace TitanArmyControl.Core.Tests;

public sealed class ContractTests
{
    [Fact]
    public void ProfileMatchesSharedContract()
    {
        using var document = JsonDocument.Parse(File.ReadAllText(
            Path.Combine(AppContext.BaseDirectory, "contracts", "profile.contract.json")));
        var root = document.RootElement;

        Assert.Equal(TitanArmyProfile.ModelName, root.GetProperty("model").GetProperty("name").GetString());
        Assert.Equal(
            VcpCode.Brightness,
            Hex(root.GetProperty("standardVcp").GetProperty("brightness").GetString()));
        Assert.Equal(
            VcpCode.Vendor.SceneMode,
            Hex(root.GetProperty("vendorVcp").GetProperty("sceneMode").GetString()));
        Assert.Equal(
            VcpCode.Vendor.Selector,
            Hex(root.GetProperty("ddc").GetProperty("vendorSelector").GetString()));

        var scenes = root.GetProperty("sceneModes");
        Assert.Equal((int)TitanArmyProfile.SceneMode.Standard, scenes.GetProperty("standard").GetInt32());
        Assert.Equal((int)TitanArmyProfile.SceneMode.Fps, scenes.GetProperty("fps").GetInt32());
        Assert.Equal((int)TitanArmyProfile.SceneMode.Custom, scenes.GetProperty("custom").GetInt32());

        var official = root.GetProperty("officialSettings");
        foreach (var setting in Enum.GetValues<TitanArmyProfile.WindowsSetting>())
        {
            var entry = official.GetProperty(setting.ContractKey());
            Assert.Equal(setting.Register(), Hex(entry.GetProperty("register").GetString()));

            var range = entry.GetProperty("range");
            Assert.Equal(setting.AllowedRange().Minimum, range[0].GetInt32());
            Assert.Equal(setting.AllowedRange().Maximum, range[1].GetInt32());
        }
    }

    [Fact]
    public void FramingMatchesSharedVectors()
    {
        using var document = JsonDocument.Parse(File.ReadAllText(
            Path.Combine(AppContext.BaseDirectory, "contracts", "ddc-vectors.json")));

        foreach (var vector in document.RootElement.GetProperty("vectors").EnumerateArray())
        {
            var vcp = Hex(vector.GetProperty("vcp").GetString());
            var expected = vector.GetProperty("bytes")
                .EnumerateArray()
                .Select(value => Hex(value.GetString()))
                .ToArray();

            var actual = vector.TryGetProperty("value", out var value)
                ? DdcFraming.WriteRequest(vcp, checked((ushort)value.GetInt32()))
                : DdcFraming.ReadRequest(vcp);

            Assert.Equal(expected, actual);
        }
    }

    private static byte Hex(string? value)
    {
        Assert.NotNull(value);
        Assert.StartsWith("0x", value, StringComparison.OrdinalIgnoreCase);
        return Convert.ToByte(value[2..], 16);
    }
}
