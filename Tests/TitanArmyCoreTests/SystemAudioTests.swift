import CoreAudio
import XCTest
@testable import TitanArmyCore

final class SystemAudioTests: XCTestCase {
    private func endpoint(_ id: UInt32, _ uid: String, _ name: String, alive: Bool = true, channels: Int = 2) -> AudioEndpoint {
        AudioEndpoint(id: id, uid: uid, name: name, transport: 0, isAlive: alive, outputChannels: channels)
    }
    func testMatchesOnlyTheSelectedDisplay() throws {
        let target = endpoint(1, "display", "P275MV PLUS")
        let builtIn = endpoint(2, "builtin", "Mac mini Speakers")
        XCTAssertEqual(try SystemAudio.matchingDisplay("p275mv plus", in: [builtIn, target]).id, 1)
    }
    func testRejectsAmbiguousNamesInsteadOfRoutingToTheFirstDevice() {
        let devices = [endpoint(1, "one", "P275MV PLUS"), endpoint(2, "two", "P275MV PLUS")]
        XCTAssertThrowsError(try SystemAudio.matchingDisplay("P275MV PLUS", in: devices))
    }
    func testDoesNotSelectTheVirtualEndpointAsItsOwnTarget() {
        XCTAssertThrowsError(try SystemAudio.matchingDisplay("P275MV PLUS", in: [endpoint(1, SystemAudio.driverUID, "P275MV PLUS")]))
        XCTAssertThrowsError(try SystemAudio.setTargetUID(SystemAudio.driverUID, on: 0))
    }
    func testRejectsDeadAndInputOnlyEndpoints() {
        let devices = [endpoint(1, "dead", "P275MV PLUS", alive: false), endpoint(2, "input", "P275MV PLUS", channels: 0)]
        XCTAssertThrowsError(try SystemAudio.matchingDisplay("P275MV PLUS", in: devices))
    }
    func testRejectsMalformedRoutingAndNonFiniteVolumeBeforeHALCalls() {
        XCTAssertThrowsError(try SystemAudio.setTargetUID("", on: 0))
        XCTAssertThrowsError(try SystemAudio.setTargetUID(String(repeating: "x", count: 513), on: 0))
        XCTAssertThrowsError(try SystemAudio.setVolume(.nan, on: 0))
        XCTAssertThrowsError(try SystemAudio.setVolume(.infinity, on: 0))
    }
}
