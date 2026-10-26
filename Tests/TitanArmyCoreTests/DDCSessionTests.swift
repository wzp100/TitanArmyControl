import XCTest
@testable import TitanArmyCore

final class DDCSessionTests: XCTestCase {
    private func makeSession(_ transport: FakeTransport) -> DDCSession {
        var timing = DDCSession.Timing()
        // Tests run far faster than real hardware while keeping the same logic.
        timing.readDelay = 100
        timing.writeDelay = 100
        timing.settleDelay = 100
        timing.readAttempts = 8
        timing.verifyAttempts = 6
        return DDCSession(transport: transport, timing: timing)
    }

    func testReadSkipsGarbageReplies() throws {
        let transport = FakeTransport()
        transport.registers[0x10] = .init(maximum: 100, current: 62)
        transport.garbageReadsRemaining[0x10] = 3
        let session = makeSession(transport)

        let reply = try session.read(0x10)
        XCTAssertEqual(reply.current, 62)
    }

    func testReadFailsAfterExhaustingAttempts() {
        let transport = FakeTransport()
        transport.registers[0x10] = .init(maximum: 100, current: 62)
        transport.garbageReadsRemaining[0x10] = 999
        let session = makeSession(transport)

        XCTAssertThrowsError(try session.read(0x10)) { error in
            XCTAssertEqual(error as? DDCError, .noValidReply(vcp: 0x10))
        }
    }

    func testUnsupportedRegisterSurfacesAsSuch() {
        let transport = FakeTransport()
        transport.unsupported = [0x3A]
        let session = makeSession(transport)

        XCTAssertThrowsError(try session.read(0x3A)) { error in
            XCTAssertEqual(error as? DDCError, .unsupported(vcp: 0x3A))
        }
    }

    func testWriteVerifiesAndApplies() throws {
        let transport = FakeTransport()
        transport.registers[0x10] = .init(maximum: 100, current: 100)
        let session = makeSession(transport)

        let reply = try session.write(0x10, value: 40)
        XCTAssertEqual(reply.current, 40)
        XCTAssertEqual(transport.registers[0x10]?.current, 40)
    }

    func testWriteRejectsValueAboveMaximumBeforeSending() {
        let transport = FakeTransport()
        transport.registers[0x10] = .init(maximum: 100, current: 50)
        let session = makeSession(transport)

        XCTAssertThrowsError(try session.write(0x10, value: 40000)) { error in
            XCTAssertEqual(
                error as? DDCError, .outOfRange(vcp: 0x10, value: 40000, maximum: 100)
            )
        }
        XCTAssertEqual(transport.registers[0x10]?.current, 50)
    }

    /// The exact hardware failure mode: I2C accepts the write, the panel keeps
    /// its old value. This must be an error, never a silent success.
    func testWriteReportsNotAppliedWhenPanelIgnoresIt() {
        let transport = FakeTransport()
        transport.registers[0x10] = .init(
            maximum: 100, current: 100, writable: true,
            locksWritesWhen: { $0 != 100 }
        )
        let session = makeSession(transport)

        XCTAssertThrowsError(try session.write(0x10, value: 40)) { error in
            XCTAssertEqual(error as? DDCError, .notApplied(vcp: 0x10, requested: 40, observed: 100))
        }
    }

    func testTransportFailureIsPropagated() {
        let transport = FakeTransport()
        transport.registers[0x62] = .init(maximum: 100, current: 50)
        transport.writeStatus = kIOReturnNoDevice
        let session = makeSession(transport)

        XCTAssertThrowsError(try session.write(0x62, value: 10)) { error in
            guard case .transportFailure = error as? DDCError else {
                return XCTFail("expected transportFailure, got \(error)")
            }
        }
    }

    func testSnapshotCollectsPartialFailures() {
        let transport = FakeTransport()
        transport.registers[0x10] = .init(maximum: 100, current: 70)
        transport.registers[0x62] = .init(maximum: 100, current: 20)
        transport.unsupported = [0x12]
        let session = makeSession(transport)

        let snapshot = session.snapshot(hdrEnabled: false)
        XCTAssertTrue(snapshot.brightness.available)
        XCTAssertEqual(snapshot.brightness.value, 70)
        XCTAssertTrue(snapshot.volume.available)
        XCTAssertFalse(snapshot.contrast.available)
    }

    func testThoroughSnapshotReadsExtendedDiagnostics() {
        let transport = FakeTransport()
        transport.registers[0x10] = .init(maximum: 100, current: 20)
        transport.registers[0x14] = .init(maximum: 12, current: 5)
        transport.registers[0x16] = .init(maximum: 100, current: 48)
        transport.registers[0x60] = .init(maximum: 18, current: 15)
        transport.registers[0xC0] = .init(maximum: 65535, current: 5441)
        let session = makeSession(transport)

        let snapshot = session.snapshot(hdrEnabled: false, thorough: true)
        XCTAssertEqual(snapshot.gamma.value, 5)
        XCTAssertEqual(snapshot.redGain.value, 48)
        XCTAssertEqual(snapshot.inputSource.value, 15)
        XCTAssertEqual(snapshot.usageTime.value, 5441)
    }
}
