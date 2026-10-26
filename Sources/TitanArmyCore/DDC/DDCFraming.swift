import Foundation

/// Pure DDC/CI framing. No I/O happens here, so every rule is unit-testable.
///
/// This encodes the exact byte layout that was verified against a real
/// Titan Army P275MV PLUS on Apple Silicon. The two constants below are not
/// arbitrary: `0x6E` is the monitor's DDC/CI source address and `0x51` is the
/// host destination address, and both participate in the checksum.
public enum DDCFraming {
    /// DDC/CI source address used by the display when replying.
    public static let monitorAddress: UInt8 = 0x6E
    /// DDC/CI host destination address.
    public static let hostAddress: UInt8 = 0x51
    /// Address byte that participates in the reply checksum (verified in situ).
    static let replyChecksumSalt: UInt8 = 0x50

    /// Get VCP Feature request: `82 01 <vcp> <ck>`.
    public static func readRequest(vcp: UInt8) -> [UInt8] {
        let payload: [UInt8] = [0x82, 0x01, vcp]
        return payload + [checksum(for: payload)]
    }

    /// Set VCP Feature request: `84 03 <vcp> <hi> <lo> <ck>`.
    public static func writeRequest(vcp: UInt8, value: UInt16) -> [UInt8] {
        let payload: [UInt8] = [0x84, 0x03, vcp, UInt8(value >> 8), UInt8(value & 0xFF)]
        return payload + [checksum(for: payload)]
    }

    /// Raw DDC/CI command; used only by bounded vendor-specific protocol rules.
    public static func request(payload: [UInt8]) -> [UInt8] {
        return payload + [checksum(for: payload)]
    }

    /// Checksum over a host→monitor payload.
    ///
    /// The monitor addresses are folded in, so `checksum(for: [0x82, 0x01, 0x10])`
    /// is `0xAC` — the value that this panel actually accepts.
    public static func checksum(for payload: [UInt8]) -> UInt8 {
        payload.reduce(monitorAddress ^ hostAddress) { $0 ^ $1 }
    }

    /// Validates a reply checksum.
    ///
    /// Measured replies satisfy `xor(bytes[0...9]) ^ 0x50 == checksum`.
    public static func isValidChecksum(_ reply: [UInt8]) -> Bool {
        guard reply.count >= 11 else { return false }
        let computed = reply[0..<10].reduce(replyChecksumSalt) { $0 ^ $1 }
        return computed == reply[10]
    }
}

/// A decoded Get VCP Feature reply.
public struct VCPReply: Equatable, Sendable {
    public enum Result: UInt8, Sendable {
        case success = 0x00
        case unsupported = 0x01
    }

    public let vcp: UInt8
    public let result: Result
    /// 0 = continuous (a range), 1 = non-continuous (a list of values).
    public let isContinuous: Bool
    public let maximum: Int
    public let current: Int

    /// Whether the reported values are internally consistent.
    ///
    /// Some firmware answers VCP `0xF3` with a tiny maximum but a 16-bit current
    /// value that cannot belong to it. Such a reply is syntactically valid yet
    /// meaningless, so it is rejected rather than shown as a huge number.
    public var isPlausible: Bool {
        guard result == .success else { return true }
        return current <= maximum
    }

    /// Decodes and fully validates a raw 11-byte reply.
    ///
    /// Returns `nil` for anything that is not a well-formed reply for `vcp`.
    /// Real panels drop or corrupt replies often enough that rejecting garbage
    /// is mandatory: during bring-up, roughly 1 in 10 raw reads was junk.
    public static func decode(_ raw: [UInt8], expecting vcp: UInt8) -> VCPReply? {
        guard raw.count >= 11 else { return nil }
        guard raw[0] == DDCFraming.monitorAddress else { return nil }
        guard raw[2] == 0x02 else { return nil }
        guard raw[4] == vcp else { return nil }
        guard DDCFraming.isValidChecksum(raw) else { return nil }
        guard let result = Result(rawValue: raw[3]) else { return nil }
        let maximum = Int(raw[6]) << 8 | Int(raw[7])
        let current = Int(raw[8]) << 8 | Int(raw[9])
        let reply = VCPReply(
            vcp: vcp,
            result: result,
            isContinuous: raw[5] == 0x00,
            maximum: maximum,
            current: current
        )
        guard reply.isPlausible else { return nil }
        return reply
    }
}
