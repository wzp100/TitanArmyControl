namespace TitanArmyControl.Core.Ddc;

/// <summary>
/// Portable DDC/CI framing rules. Windows normally lets DXVA2 frame requests,
/// but keeping the protocol here makes diagnostics and tests platform-neutral.
/// </summary>
public static class DdcFraming
{
    public const byte MonitorAddress = 0x6E;
    public const byte HostAddress = 0x51;
    private const byte ReplyChecksumSalt = 0x50;

    public static byte[] ReadRequest(byte vcp) =>
        WithChecksum([0x82, 0x01, vcp]);

    public static byte[] WriteRequest(byte vcp, ushort value) =>
        WithChecksum([0x84, 0x03, vcp, (byte)(value >> 8), (byte)value]);

    public static byte[] Request(ReadOnlySpan<byte> payload)
    {
        var result = new byte[payload.Length + 1];
        payload.CopyTo(result);
        result[^1] = Checksum(payload);
        return result;
    }

    public static byte Checksum(ReadOnlySpan<byte> payload)
    {
        var result = (byte)(MonitorAddress ^ HostAddress);
        foreach (var value in payload)
        {
            result ^= value;
        }

        return result;
    }

    public static bool IsValidReply(ReadOnlySpan<byte> reply)
    {
        if (reply.Length < 11)
        {
            return false;
        }

        byte computed = ReplyChecksumSalt;
        for (var index = 0; index < 10; index++)
        {
            computed ^= reply[index];
        }

        return computed == reply[10];
    }

    private static byte[] WithChecksum(ReadOnlySpan<byte> payload)
    {
        var result = new byte[payload.Length + 1];
        payload.CopyTo(result);
        result[^1] = Checksum(payload);
        return result;
    }
}

public readonly record struct VcpReply(
    byte Vcp,
    bool Success,
    bool IsContinuous,
    ushort Maximum,
    ushort Current)
{
    public bool IsPlausible => !Success || Current <= Maximum;

    public static VcpReply? Decode(ReadOnlySpan<byte> raw, byte expectedVcp)
    {
        if (raw.Length < 11 ||
            raw[0] != DdcFraming.MonitorAddress ||
            raw[2] != 0x02 ||
            raw[4] != expectedVcp ||
            !DdcFraming.IsValidReply(raw) ||
            raw[3] is not (0x00 or 0x01))
        {
            return null;
        }

        var result = new VcpReply(
            expectedVcp,
            raw[3] == 0x00,
            raw[5] == 0x00,
            (ushort)((raw[6] << 8) | raw[7]),
            (ushort)((raw[8] << 8) | raw[9]));

        return result.IsPlausible ? result : null;
    }
}
