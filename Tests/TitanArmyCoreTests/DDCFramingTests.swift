import XCTest
@testable import TitanArmyCore

final class DDCFramingTests: XCTestCase {
    /// Checksums below were read from a real P275MV PLUS on this Mac.
    func testReadRequestMatchesHardware() {
        for (vcp, expected) in [(UInt8(0x10), UInt8(0xAC)), (0x12, 0xAE), (0x60, 0xDC)] {
            let packet = DDCFraming.readRequest(vcp: vcp)
            XCTAssertEqual(packet.count, 4)
            XCTAssertEqual(packet, [0x82, 0x01, vcp, expected])
        }
    }

    func testWriteRequestMatchesHardware() {
        // 6E^51^84^03^10^00^64 = 0xCC, the value this panel accepts for 100%.
        XCTAssertEqual(
            DDCFraming.writeRequest(vcp: 0x10, value: 100),
            [0x84, 0x03, 0x10, 0x00, 0x64, 0xCC]
        )
        XCTAssertEqual(
            DDCFraming.writeRequest(vcp: 0x62, value: 0x0064),
            [0x84, 0x03, 0x62, 0x00, 0x64, 0xBE]
        )
    }

    func testReadRequestRoundTripsThroughDecoder() {
        // Craft the reply a panel would send for a success to 0x10 max/cur 100.
        let reply = makeReply(vcp: 0x10, result: 0, type: 0, max: 100, current: 100)
        let decoded = VCPReply.decode(reply, expecting: 0x10)
        XCTAssertEqual(decoded?.current, 100)
        XCTAssertEqual(decoded?.maximum, 100)
        XCTAssertEqual(decoded?.result, .success)
        XCTAssertEqual(decoded?.isContinuous, true)
    }

    func testDecoderRejectsMalformedReplies() {
        let good = makeReply(vcp: 0x10, result: 0, type: 0, max: 100, current: 64)
        XCTAssertNotNil(VCPReply.decode(good, expecting: 0x10))

        // Wrong VCP echo — this is what a stale buffer looks like.
        XCTAssertNil(VCPReply.decode(good, expecting: 0x12))
        // Corrupted checksum.
        var badChecksum = good
        badChecksum[10] ^= 0xFF
        XCTAssertNil(VCPReply.decode(badChecksum, expecting: 0x10))
        // Wrong source address.
        var badSource = good
        badSource[0] = 0x50
        XCTAssertNil(VCPReply.decode(badSource, expecting: 0x10))
        // Truncated.
        XCTAssertNil(VCPReply.decode(Array(good.prefix(8)), expecting: 0x10))
    }

    func testUnsupportedIsDecodedButFlagged() {
        let reply = makeReply(vcp: 0x3A, result: 1, type: 1, max: 0xFFFF, current: 0)
        let decoded = VCPReply.decode(reply, expecting: 0x3A)
        XCTAssertEqual(decoded?.result, .unsupported)
    }

    /// Real firmware answers VCP 0xF3 with max 4 but current 63869. That reply is
    /// well-formed yet impossible, and must be rejected instead of displayed.
    func testImplausibleCurrentValueIsRejected() {
        let reply = makeReply(vcp: 0xF3, result: 0, type: 1, max: 4, current: 63869)
        XCTAssertTrue(DDCFraming.isValidChecksum(reply))
        XCTAssertNil(VCPReply.decode(reply, expecting: 0xF3))

        // A legitimate value for the same register still decodes.
        let valid = makeReply(vcp: 0xF3, result: 0, type: 1, max: 4, current: 3)
        XCTAssertEqual(VCPReply.decode(valid, expecting: 0xF3)?.current, 3)
    }

    /// Builds a panel reply using the same checksum rule the hardware uses.
    func makeReply(
        vcp: UInt8, result: UInt8, type: UInt8, max: Int, current: Int
    ) -> [UInt8] {
        var bytes: [UInt8] = [
            DDCFraming.monitorAddress, 0x88, 0x02, result, vcp, type,
            UInt8(max >> 8), UInt8(max & 0xFF), UInt8(current >> 8), UInt8(current & 0xFF),
        ]
        bytes.append(bytes.reduce(0x50) { $0 ^ $1 })
        return bytes
    }
}
