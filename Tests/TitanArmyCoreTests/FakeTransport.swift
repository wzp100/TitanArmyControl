import Foundation
import IOKit
@testable import TitanArmyCore

/// Scriptable in-memory DDC transport.
///
/// Lets the retry/verify logic be tested against the failure modes actually seen
/// on hardware: dropped replies, stale buffers, and writes that are accepted but
/// never adopted.
final class FakeTransport: DDCTransport, @unchecked Sendable {
    struct Register {
        var maximum: Int
        var current: Int
        var writable: Bool = true
        /// When set, writes report success but the value never changes.
        var locksWritesWhen: ((UInt16) -> Bool)? = nil
    }

    let endpoint = DDCEndpoint(
        chipAddress: 0x37, dataAddress: 0x51, servicePath: "fake", isMCDP29XX: false
    )

    var registers: [UInt8: Register] = [:]
    /// Number of initial reads per VCP that return garbage.
    var garbageReadsRemaining: [UInt8: Int] = [:]
    /// VCPs the panel claims not to support.
    var unsupported: Set<UInt8> = []
    var writeStatus: IOReturn = KERN_SUCCESS
    var replyWriteStatus: IOReturn = KERN_SUCCESS
    /// Records every value sent to a VCP, used to verify sequential controls.
    var writtenValues: [UInt8: [Int]] = [:]
    /// Private vendor commands intentionally have no readable register model.
    var vendorWrittenValues: [UInt8: [Int]] = [:]
    private(set) var vendorWriteCount = 0

    private(set) var writeCount = 0
    private var pendingVCP: UInt8?
    private var lastReply: [UInt8] = []

    func write(_ payload: [UInt8]) -> IOReturn {
        writeCount += 1
        if payload.count == 4, payload[0] == 0x82 {
            pendingVCP = payload[2]
            return replyWriteStatus
        }
        if payload.count == 6, payload[0] == 0x84 {
            let vcp = payload[2]
            let value = Int(UInt16(payload[3]) << 8 | UInt16(payload[4]))
            pendingVCP = nil
            guard writeStatus == KERN_SUCCESS else { return writeStatus }
            guard var register = registers[vcp], register.writable else {
                vendorWrittenValues[vcp, default: []].append(value)
                vendorWriteCount += 1
                return writeStatus
            }
            if register.locksWritesWhen?(UInt16(value)) ?? false { return writeStatus }
            writtenValues[vcp, default: []].append(value)
            register.current = min(value, register.maximum)
            registers[vcp] = register
            return writeStatus
        }
        return kIOReturnBadArgument
    }

    func read(count: Int) -> (bytes: [UInt8], status: IOReturn) {
        guard let vcp = pendingVCP else {
            return ([UInt8](repeating: 0, count: count), kIOReturnError)
        }
        pendingVCP = nil

        if var remaining = garbageReadsRemaining[vcp], remaining > 0 {
            remaining -= 1
            garbageReadsRemaining[vcp] = remaining
            return (Array(repeating: 0xA5, count: count), KERN_SUCCESS)
        }

        let isUnsupported = unsupported.contains(vcp)
        let register = registers[vcp]
        let type: UInt8 = register.map { _ in 0 } ?? 1
        var reply: [UInt8] = [
            DDCFraming.monitorAddress, 0x88, 0x02,
            isUnsupported ? 0x01 : 0x00,
            vcp, type,
            UInt8((register?.maximum ?? 0xFFFF) >> 8), UInt8((register?.maximum ?? 0xFFFF) & 0xFF),
            UInt8((register?.current ?? 0) >> 8), UInt8((register?.current ?? 0) & 0xFF),
        ]
        reply.append(reply.reduce(0x50) { $0 ^ $1 })
        lastReply = reply
        var padded = reply
        while padded.count < count { padded.append(0) }
        return (padded, KERN_SUCCESS)
    }
}
