using TitanArmyControl.Core.Protocol;

namespace TitanArmyControl.Core.Ddc;

/// <summary>
/// Serialized DDC/CI access with retries, range checks, and post-write
/// verification. All platform adapters share these behavioral rules.
/// </summary>
public sealed class DdcSession
{
    private readonly object _gate = new();

    public DdcSession(IDdcTransport transport, DdcTiming? timing = null)
    {
        Transport = transport;
        Timing = timing ?? DdcTiming.Default;
    }

    public IDdcTransport Transport { get; }
    public DdcTiming Timing { get; }
    public string Endpoint => Transport.Endpoint;

    public VcpReply Read(byte vcp)
    {
        lock (_gate)
        {
            return ReadLocked(vcp, Timing.ReadAttempts);
        }
    }

    public VcpReply? Probe(byte vcp)
    {
        lock (_gate)
        {
            try
            {
                return ReadLocked(vcp, 3);
            }
            catch (DdcException)
            {
                return null;
            }
        }
    }

    public VcpReply Write(byte vcp, ushort value)
    {
        lock (_gate)
        {
            var before = ReadLocked(vcp, Timing.ReadAttempts);
            if (!before.Success)
            {
                throw new DdcException($"VCP 0x{vcp:X2} is not supported by this display.");
            }

            if (value > before.Maximum)
            {
                throw new DdcException(
                    $"VCP 0x{vcp:X2} value {value} exceeds maximum {before.Maximum}.");
            }

            if (!Transport.Write(vcp, value))
            {
                throw new DdcException($"Transport write failed for VCP 0x{vcp:X2}.");
            }

            Delay(Timing.WriteDelay);

            var observed = before;
            for (var attempt = 0; attempt < Timing.VerifyAttempts; attempt++)
            {
                Delay(attempt == 0 ? Timing.VerifySettleDelay : Timing.WriteDelay);
                try
                {
                    observed = ReadLocked(vcp, 2);
                }
                catch (DdcException)
                {
                    continue;
                }

                if (observed.Current == value)
                {
                    return observed;
                }
            }

            throw new DdcException(
                $"VCP 0x{vcp:X2} write ignored: requested {value}, display kept {observed.Current}.");
        }
    }

    public void WriteBlind(byte vcp, ushort value, TimeSpan? delay = null)
    {
        lock (_gate)
        {
            if (!Transport.Write(vcp, value))
            {
                throw new DdcException($"Vendor transport write failed for target 0x{vcp:X2}.");
            }

            Delay(delay ?? Timing.WriteDelay);
        }
    }

    public void WriteVendorPair(
        TitanArmyProfile.WindowsSetting setting,
        ushort value,
        TimeSpan? secondWriteDelay = null)
    {
        WriteBlind(VcpCode.Vendor.Selector, value);
        WriteBlind(setting.Register(), value, secondWriteDelay);
    }

    private VcpReply ReadLocked(byte vcp, int attempts)
    {
        var sawUnsupported = false;
        string? lastError = null;

        for (var attempt = 0; attempt < Math.Max(attempts, 1); attempt++)
        {
            var reply = Transport.Read(vcp);
            if (!reply.Success)
            {
                sawUnsupported |= reply.Unsupported;
                lastError = reply.Error;
                Delay(Timing.WriteDelay);
                continue;
            }

            if (reply.Current > reply.Maximum)
            {
                lastError = "Display returned an implausible VCP range.";
                Delay(Timing.WriteDelay);
                continue;
            }

            return new VcpReply(vcp, true, false, reply.Maximum, reply.Current);
        }

        throw new DdcException(
            sawUnsupported
                ? $"VCP 0x{vcp:X2} is not supported by this display."
                : $"No valid DDC reply for VCP 0x{vcp:X2}. {lastError}".TrimEnd());
    }

    private void Delay(TimeSpan delay)
    {
        if (delay > TimeSpan.Zero)
        {
            Thread.Sleep(delay);
        }
    }
}
