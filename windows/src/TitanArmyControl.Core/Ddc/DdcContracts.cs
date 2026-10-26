namespace TitanArmyControl.Core.Ddc;

public readonly record struct DdcTransportReply(
    bool Success,
    ushort Current,
    ushort Maximum,
    string? Error,
    bool Unsupported = false)
{
    public static DdcTransportReply Failed(string error) => new(false, 0, 0, error);
}

/// <summary>
/// OS adapter seam. Implementations perform exactly one transport operation;
/// retries, validation, and verification belong to <see cref="DdcSession"/>.
/// </summary>
public interface IDdcTransport : IDisposable
{
    string Endpoint { get; }
    DdcTransportReply Read(byte vcp);
    bool Write(byte vcp, ushort value);
}

public sealed class DdcException : Exception
{
    public DdcException(string message) : base(message)
    {
    }

    public DdcException(string message, Exception innerException) : base(message, innerException)
    {
    }
}

public sealed record DdcTiming
{
    public TimeSpan ReadDelay { get; init; } = TimeSpan.FromMilliseconds(55);
    public TimeSpan WriteDelay { get; init; } = TimeSpan.FromMilliseconds(120);
    public int ReadAttempts { get; init; } = 8;
    public int VerifyAttempts { get; init; } = 6;
    public TimeSpan VerifySettleDelay { get; init; } = TimeSpan.FromMilliseconds(350);

    public static DdcTiming Default { get; } = new();
}
