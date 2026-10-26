using TitanArmyControl.Core.Ddc;

namespace TitanArmyControl.Core.Tests;

internal sealed class FakeTransport : IDdcTransport
{
    public Dictionary<byte, ushort> Values { get; } = [];
    public HashSet<byte> Unsupported { get; } = [];
    public HashSet<byte> IgnoredWrites { get; } = [];
    public List<(byte Vcp, ushort Value)> Writes { get; } = [];
    public string Endpoint => "fake";

    public DdcTransportReply Read(byte vcp)
    {
        if (Unsupported.Contains(vcp))
        {
            return new(false, 0, 0, "unsupported", Unsupported: true);
        }

        Values.TryAdd(vcp, 50);
        return new(true, Values[vcp], 100, null);
    }

    public bool Write(byte vcp, ushort value)
    {
        Writes.Add((vcp, value));
        if (!IgnoredWrites.Contains(vcp))
        {
            Values[vcp] = value;
        }

        return true;
    }

    public void Dispose()
    {
    }
}
