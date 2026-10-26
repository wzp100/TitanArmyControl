import Foundation
import IOKit

public enum DDCError: Error, Equatable {
    /// The monitor never produced a well-formed reply for this VCP.
    case noValidReply(vcp: UInt8)
    /// The monitor explicitly reported the VCP as unsupported.
    case unsupported(vcp: UInt8)
    /// I2C write failed at the platform layer.
    case transportFailure(vcp: UInt8, status: IOReturn)
    /// Write was accepted by I2C but the monitor kept the old value.
    ///
    /// This is the signature of a register that firmware locks — for example
    /// brightness on this panel while HDR is engaged.
    case notApplied(vcp: UInt8, requested: Int, observed: Int)
    case outOfRange(vcp: UInt8, value: Int, maximum: Int)
}

extension DDCError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .noValidReply(vcp):
            return String(format: "No valid DDC reply for VCP 0x%02X", vcp)
        case let .unsupported(vcp):
            return String(format: "VCP 0x%02X is not supported by this display", vcp)
        case let .transportFailure(vcp, status):
            return String(
                format: "I2C write failed for VCP 0x%02X (0x%08X)", vcp, UInt32(bitPattern: status)
            )
        case let .notApplied(vcp, requested, observed):
            return String(
                format: "VCP 0x%02X write ignored: requested %d, display kept %d",
                vcp, requested, observed
            )
        case let .outOfRange(vcp, value, maximum):
            return String(format: "VCP 0x%02X value %d exceeds maximum %d", vcp, value, maximum)
        }
    }
}

/// Serialised DDC/CI access with retries and post-write verification.
///
/// Design rules (learned from the Windows implementation and confirmed here):
/// - never trust a single read; the panel drops or garbles replies regularly;
/// - never assume a successful I2C write changed anything;
/// - never write a register that has not been read and range-checked first.
public final class DDCSession: @unchecked Sendable {
    public struct Timing: Sendable {
        /// Delay between issuing a read request and sampling the reply.
        public var readDelay: useconds_t = 55_000
        /// Delay between writes, so the scaler can absorb each command.
        public var writeDelay: useconds_t = 120_000
        /// Total read attempts before reporting failure.
        public var readAttempts = 8
        /// Attempts used when confirming that a write stuck.
        public var verifyAttempts = 6
        /// How long to wait before the first post-write verification read.
        public var settleDelay: useconds_t = 350_000
        public init() {}
    }

    public let transport: DDCTransport
    public var timing: Timing
    private let lock = NSLock()

    public init(transport: DDCTransport, timing: Timing = Timing()) {
        self.transport = transport
        self.timing = timing
    }

    public var endpoint: DDCEndpoint { transport.endpoint }

    /// Reads a VCP, retrying until a well-formed reply arrives.
    public func read(_ vcp: UInt8) throws -> VCPReply {
        lock.lock(); defer { lock.unlock() }
        return try readLocked(vcp, attempts: timing.readAttempts)
    }

    /// Reads a VCP without treating "unsupported" as an error.
    public func probe(_ vcp: UInt8) -> VCPReply? {
        lock.lock(); defer { lock.unlock() }
        return try? readLocked(vcp, attempts: 3)
    }

    /// Writes a VCP and verifies that the display actually adopted the value.
    ///
    /// - Returns: the value observed after the write.
    /// - Throws: `.notApplied` when the transport succeeded but the panel did not
    ///   change, which is how locked registers (HDR brightness) surface.
    @discardableResult
    public func write(_ vcp: UInt8, value: UInt16) throws -> VCPReply {
        lock.lock(); defer { lock.unlock() }

        let before = try readLocked(vcp, attempts: timing.readAttempts)
        guard before.result == .success else { throw DDCError.unsupported(vcp: vcp) }
        guard Int(value) <= before.maximum else {
            throw DDCError.outOfRange(vcp: vcp, value: Int(value), maximum: before.maximum)
        }

        let status = transport.write(DDCFraming.writeRequest(vcp: vcp, value: value))
        guard status == KERN_SUCCESS else {
            throw DDCError.transportFailure(vcp: vcp, status: status)
        }
        usleep(timing.writeDelay)

        var observed = before
        for attempt in 0..<timing.verifyAttempts {
            usleep(attempt == 0 ? timing.settleDelay : timing.writeDelay)
            guard let reply = try? readLocked(vcp, attempts: 2) else { continue }
            observed = reply
            if reply.current == Int(value) { return reply }
        }
        throw DDCError.notApplied(vcp: vcp, requested: Int(value), observed: observed.current)
    }

    /// Writes without requiring the value to stick. Used only for "toggle and
    /// observe" operations where read-back semantics are unknown.
    func writeBlind(_ vcp: UInt8, value: UInt16) -> IOReturn {
        lock.lock(); defer { lock.unlock() }
        let status = transport.write(DDCFraming.writeRequest(vcp: vcp, value: value))
        usleep(timing.writeDelay)
        return status
    }

    /// Sends a pre-framed vendor command and waits long enough for the scaler
    /// to absorb it. Callers own all model, range, and safety checks.
    func writeVendorCommand(_ payload: [UInt8], delay: useconds_t? = nil) -> IOReturn {
        lock.lock(); defer { lock.unlock() }
        let status = transport.write(DDCFraming.request(payload: payload))
        usleep(delay ?? timing.writeDelay)
        return status
    }

    // MARK: - Internals (caller holds `lock`)

    private func readLocked(_ vcp: UInt8, attempts: Int) throws -> VCPReply {
        var sawUnsupported = false
        for _ in 0..<max(attempts, 1) {
            let status = transport.write(DDCFraming.readRequest(vcp: vcp))
            guard status == KERN_SUCCESS else { continue }
            usleep(timing.readDelay)
            let response = transport.read(count: 12)
            guard response.status == KERN_SUCCESS,
                  let reply = VCPReply.decode(response.bytes, expecting: vcp) else { continue }
            if reply.result == .unsupported {
                sawUnsupported = true
                continue
            }
            return reply
        }
        throw sawUnsupported ? DDCError.unsupported(vcp: vcp) : DDCError.noValidReply(vcp: vcp)
    }
}
