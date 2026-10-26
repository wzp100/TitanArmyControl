import XCTest
@testable import TitanArmyCore

final class MonitorControllerTests: XCTestCase {
    private func makeController(
        hdrEnabled: Bool?,
        configure: (FakeTransport) -> Void = { _ in }
    ) -> (MonitorController, FakeTransport) {
        let transport = FakeTransport()
        configure(transport)
        var timing = DDCSession.Timing()
        timing.readDelay = 100
        timing.writeDelay = 100
        timing.settleDelay = 100
        let session = DDCSession(transport: transport, timing: timing)

        let descriptor = DisplayDescriptor(
            id: 1,
            name: "P275MV PLUS",
            manufacturer: "LHC",
            productName: "P275MV PLUS",
            vendorNumber: TitanArmyModel.vendorNumber,
            modelNumber: TitanArmyModel.modelNumber,
            displaySerial: 0,
            edidUUID: "test",
            isBuiltin: false,
            isMain: true,
            widthPixels: 3840,
            heightPixels: 2160,
            refreshRate: 160,
            supportsHDR: true,
            registryPath: nil
        )
        let controller = MonitorController(
            descriptor: descriptor,
            session: session,
            hdrControl: .init(
                isEnabled: { _ in hdrEnabled },
                setEnabled: { _, _ in true }
            )
        )
        return (controller, transport)
    }

    func testBrightnessIsRefusedWhileHDREngaged() {
        let (controller, transport) = makeController(hdrEnabled: true) {
            $0.registers[0x10] = .init(maximum: 100, current: 100, writable: true)
        }

        XCTAssertThrowsError(try controller.setBrightness(percent: 30)) { error in
            XCTAssertEqual(error as? MonitorController.Failure, .toneLockedByHDR)
        }
        // The critical property: nothing may reach the monitor.
        XCTAssertEqual(transport.writeCount, 0)
    }

    func testBrightnessScalesToReportedMaximum() throws {
        let (controller, transport) = makeController(hdrEnabled: false) {
            // A panel whose brightness register is not 0...100.
            $0.registers[0x10] = .init(maximum: 255, current: 255)
        }

        try controller.setBrightness(percent: 50)
        XCTAssertEqual(transport.registers[0x10]?.current, 128)
    }

    func testContrastWorksWhenHDROff() throws {
        let (controller, transport) = makeController(hdrEnabled: false) {
            $0.registers[0x12] = .init(maximum: 100, current: 50)
        }
        try controller.setContrast(percent: 70)
        XCTAssertEqual(transport.registers[0x12]?.current, 70)
    }

    func testVolumeWorksWhileHDREngaged() throws {
        let (controller, transport) = makeController(hdrEnabled: true) {
            $0.registers[0x62] = .init(maximum: 100, current: 100)
        }
        try controller.setVolume(percent: 35)
        XCTAssertEqual(transport.registers[0x62]?.current, 35)
        // One absolute write, verified by read-back; no zero-then-step ramp.
        XCTAssertEqual(transport.writtenValues[0x62], [35])
    }

    func testStandardToneUsesOfficialLiteralRange() throws {
        let (controller, transport) = makeController(hdrEnabled: false) {
            $0.registers[0x10] = .init(maximum: 100, current: 50)
            $0.registers[0x12] = .init(maximum: 100, current: 50)
        }

        try controller.setStandardTone(percent: 70, register: .brightness)
        try controller.setStandardTone(percent: 60, register: .contrast)
        XCTAssertEqual(transport.registers[0x10]?.current, 70)
        XCTAssertEqual(transport.registers[0x12]?.current, 60)
    }

    func testStandardToneIsLockedWithHDR() {
        let (controller, _) = makeController(hdrEnabled: true) {
            $0.registers[0x10] = .init(maximum: 100, current: 50)
        }

        XCTAssertThrowsError(
            try controller.setStandardTone(percent: 70, register: .brightness)
        ) { error in
            XCTAssertEqual(error as? MonitorController.Failure, .toneLockedByHDR)
        }
    }

    func testGammaWritesOnlyWithHDROff() throws {
        let (controller, transport) = makeController(hdrEnabled: false) {
            $0.registers[0x14] = .init(maximum: 12, current: 5)
        }
        try controller.setGamma(value: 7)
        XCTAssertEqual(transport.registers[0x14]?.current, 7)
    }

    func testGammaIsRefusedWhileHDREngaged() {
        let (controller, transport) = makeController(hdrEnabled: true) {
            $0.registers[0x14] = .init(maximum: 12, current: 5)
        }
        XCTAssertThrowsError(try controller.setGamma(value: 7)) { error in
            XCTAssertEqual(error as? MonitorController.Failure, .toneLockedByHDR)
        }
        XCTAssertEqual(transport.writeCount, 0)
    }

    func testColorGainScalesToPanelMaximum() throws {
        let (controller, transport) = makeController(hdrEnabled: false) {
            $0.registers[0x16] = .init(maximum: 100, current: 48)
            $0.registers[0x18] = .init(maximum: 100, current: 50)
            $0.registers[0x1A] = .init(maximum: 100, current: 49)
        }
        try controller.setColorGain(.red, percent: 60)
        try controller.setColorGain(.green, percent: 55)
        try controller.setColorGain(.blue, percent: 52)
        XCTAssertEqual(transport.registers[0x16]?.current, 60)
        XCTAssertEqual(transport.registers[0x18]?.current, 55)
        XCTAssertEqual(transport.registers[0x1A]?.current, 52)
    }

    func testMuteIsWritableAndVerified() throws {
        let (controller, transport) = makeController(hdrEnabled: true) {
            $0.registers[0x8D] = .init(maximum: 1, current: 0)
        }
        try controller.setMuted(true)
        XCTAssertEqual(transport.registers[0x8D]?.current, 1)
    }

    func testOfficialSceneWritesSelectorThenTarget() throws {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }

        try controller.setSceneMode(.fps)
        XCTAssertEqual(transport.vendorWriteCount, 2)
        XCTAssertEqual(transport.vendorWrittenValues[0x99], [6])
        XCTAssertEqual(transport.vendorWrittenValues[0x22], [6])
    }

    func testOfficialSceneValueSetIsComplete() {
        XCTAssertEqual(
            Set(TitanArmyProfile.SceneMode.allCases.map(\.rawValue)),
            [2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32]
        )
    }

    func testColorTemperatureWritesOfficialTarget() throws {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }

        try controller.setColorTemperature(.cold)
        XCTAssertEqual(transport.vendorWrittenValues[0x99], [8])
        XCTAssertEqual(transport.vendorWrittenValues[0x14], [8])
    }

    func testMonitorHDRUsesCorrectedOfficialTarget() throws {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }

        try controller.setVendorHDR(.movie)
        XCTAssertEqual(transport.vendorWrittenValues[0x99], [3])
        XCTAssertEqual(transport.vendorWrittenValues[0x4A], [3])
    }

    func testRemainingOfficialMappings() throws {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }

        try controller.setDynamicOverdrive(.topspeed)
        try controller.setDyDsULL(.level8)
        try controller.setNightVision(.autoLevel2)
        try controller.setSharpness(.level4)
        try controller.setLowBlueLight(.level4)
        try controller.setAdaptiveSync(true)
        XCTAssertEqual(transport.vendorWrittenValues[0x49], [4])
        XCTAssertEqual(transport.vendorWrittenValues[0x48], [8])
        XCTAssertEqual(transport.vendorWrittenValues[0x66], [4])
        XCTAssertEqual(transport.vendorWrittenValues[0x87], [4])
        XCTAssertEqual(transport.vendorWrittenValues[0xD8], [4])
        XCTAssertEqual(transport.vendorWrittenValues[0xE4], [1])
    }

    func testOfficialGameControlsAndOutputRange() throws {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }

        try controller.setOfficialGamma(.sCurve)
        try controller.setGameRush(true)
        try controller.setRGBOutputRange(.full)
        XCTAssertEqual(transport.vendorWrittenValues[0x99], [12, 1, 2])
        XCTAssertEqual(transport.vendorWrittenValues[0x26], [12])
        XCTAssertEqual(transport.vendorWrittenValues[0x43], [1])
        XCTAssertEqual(transport.vendorWrittenValues[0x55], [2])
    }

    func testEnhancementRangesUseOfficialTargets() throws {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }

        try controller.setEnhancement(.colorEnhance, value: 10)
        try controller.setEnhancement(.crEnhance, value: 5)
        try controller.setEnhancement(.shadowBalance, value: 100)
        try controller.setEnhancement(.superResolution, value: 5)
        try controller.setEnhancement(.haloControl, value: 88)
        XCTAssertEqual(transport.vendorWrittenValues[0x99], [10, 5, 100, 5, 88])
        XCTAssertEqual(transport.vendorWrittenValues[0x40], [10])
        XCTAssertEqual(transport.vendorWrittenValues[0x41], [5])
        XCTAssertEqual(transport.vendorWrittenValues[0x42], [100])
        XCTAssertEqual(transport.vendorWrittenValues[0x44], [5])
        XCTAssertEqual(transport.vendorWrittenValues[0x9D], [88])
    }

    func testCustomSceneUsesOfficialSceneThenTarget() throws {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }

        try controller.setCustomScene(.saturation, value: 55)
        XCTAssertEqual(transport.vendorWrittenValues[0x99], [0x20, 55])
        XCTAssertEqual(transport.vendorWrittenValues[0x22], [0x20])
        XCTAssertEqual(transport.vendorWrittenValues[0x59], [55])

        try controller.setCustomScene(.gamma, value: 4)
        XCTAssertEqual(transport.vendorWrittenValues[0x99], [0x20, 55, 4])
        XCTAssertEqual(transport.vendorWrittenValues[0x5A], [4])
    }

    func testSameToggleWriteIsSkippedLikeOfficialApp() throws {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }

        try controller.setGameRush(true)
        try controller.setGameRush(true)
        XCTAssertEqual(transport.vendorWriteCount, 2)
        XCTAssertEqual(transport.vendorWrittenValues[0x99], [1])

        controller.resetVendorStateCache()
        try controller.setGameRush(true)
        XCTAssertEqual(transport.vendorWriteCount, 4)
    }

    func testEnhancementValuesAreRangeCheckedBeforeWriting() {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }

        XCTAssertThrowsError(try controller.setEnhancement(.colorEnhance, value: 11)) { error in
            XCTAssertEqual(
                error as? MonitorController.Failure,
                .valueOutOfRange(.colorEnhance)
            )
        }
        XCTAssertEqual(transport.vendorWriteCount, 0)
    }

    func testGameAssistantMappingsUseOfficialCommandValues() throws {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }

        try controller.setGameAssistant(.screenSize(.inch32))
        try controller.setGameAssistant(.refreshPosition(.bottomLeft))
        try controller.setGameAssistant(.crosshairShape(.shape6))
        try controller.setGameAssistant(.crosshairColor(.automatic))
        try controller.setGameAssistant(.stopwatchTime(.minutes60))
        try controller.setGameAssistant(.stopwatchPosition(.topLeft))
        try controller.setGameAssistant(.gameTimeValue(.minutes45))
        try controller.setGameAssistant(.gameTimePosition(.bottomRight))
        try controller.setGameAssistant(.magnifierSize(.large))
        try controller.setGameAssistant(.magnification(.x4))
        try controller.setGameAssistant(.magnifierPosition(.central))

        XCTAssertEqual(transport.vendorWrittenValues[0x99], [4, 3, 0, 0, 0, 6, 7, 3, 1, 2, 2, 3, 2, 4])
        XCTAssertEqual(transport.vendorWrittenValues[0xA6], [4])
        XCTAssertEqual(transport.vendorWrittenValues[0x84], [3])
        XCTAssertEqual(transport.vendorWrittenValues[0x88], [6])
        XCTAssertEqual(transport.vendorWrittenValues[0x86], [7])
        XCTAssertEqual(transport.vendorWrittenValues[0x8A], [3])
        XCTAssertEqual(transport.vendorWrittenValues[0x8E], [1])
        XCTAssertEqual(transport.vendorWrittenValues[0x90], [2])
        XCTAssertEqual(transport.vendorWrittenValues[0x92], [2])
        XCTAssertEqual(transport.vendorWrittenValues[0x9C], [3])
        XCTAssertEqual(transport.vendorWrittenValues[0xB0], [2])
        XCTAssertEqual(transport.vendorWrittenValues[0x94], [4])
    }

    func testGameAssistantToggleMappings() throws {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }

        try controller.setGameAssistant(.alignment(.on))
        try controller.setGameAssistant(.magnifier(.on))
        try controller.setGameAssistant(.stopwatch(.on))
        try controller.setGameAssistant(.gameTime(.on))
        try controller.setGameAssistant(.crosshair(.on))
        try controller.setGameAssistant(.hawkEye(.on))

        XCTAssertEqual(transport.vendorWrittenValues[0x99], [1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1])
        XCTAssertEqual(transport.vendorWrittenValues[0xA8], [1])
        XCTAssertEqual(transport.vendorWrittenValues[0x9E], [1])
        XCTAssertEqual(transport.vendorWrittenValues[0x78], [1, 0, 0])
        XCTAssertEqual(transport.vendorWrittenValues[0x7A], [0, 1, 0])
        XCTAssertEqual(transport.vendorWrittenValues[0x74], [0, 0, 1])
        XCTAssertEqual(transport.vendorWrittenValues[0x91], [1])
    }

    func testExclusiveGameAssistantEnablesClearOtherOverlays() throws {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }

        try controller.setGameAssistant(.stopwatch(.on))
        XCTAssertEqual(transport.vendorWrittenValues[0x78], [1])
        XCTAssertEqual(transport.vendorWriteCount, 8)

        try controller.setGameAssistant(.crosshair(.on))
        XCTAssertEqual(transport.vendorWrittenValues[0x74], [0, 1])
        XCTAssertEqual(transport.vendorWrittenValues[0x78], [1, 0])
        XCTAssertEqual(transport.vendorWriteCount, 16)

        controller.resetVendorStateCache()
        try controller.setGameAssistant(.refreshPosition(.topLeft))
        XCTAssertEqual(transport.vendorWrittenValues[0x84], [0, 0, 1])
        XCTAssertEqual(transport.vendorWrittenValues[0x74], [0, 1, 0])
        XCTAssertEqual(transport.vendorWrittenValues[0x78], [1, 0, 0])
        XCTAssertEqual(transport.vendorWrittenValues[0x7A], [0, 0, 0])
        XCTAssertEqual(transport.vendorWriteCount, 24)
    }

    func testSettingsSharingATargetDoNotSkipEachOther() throws {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }

        // Dynamic OD and Custom Dynamic OD both drive 0x49. Returning to the
        // first value must be resent because the panel now holds the second.
        try controller.setDynamicOverdrive(.level3)
        try controller.setCustomScene(.dynamicOverdrive, value: 0)
        try controller.setDynamicOverdrive(.level3)
        XCTAssertEqual(transport.vendorWrittenValues[0x49], [3, 0, 3])
    }

    func testClearedOverlayValueCanStillBeSelected() throws {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }

        try controller.setGameAssistant(.crosshair(.on))
        XCTAssertEqual(transport.vendorWrittenValues[0x84], [0])

        // Top Right is value 0, the same value the clear wrote; an explicit
        // selection must still reach the display.
        try controller.setGameAssistant(.refreshPosition(.topRight))
        XCTAssertEqual(transport.vendorWrittenValues[0x84], [0, 0])
    }

    func testOutOfRangeCustomValueWritesNothing() {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }

        XCTAssertThrowsError(try controller.setCustomScene(.gamma, value: 50)) { error in
            XCTAssertEqual(error as? MonitorController.Failure, .valueOutOfRange(.customSceneGamma))
        }
        XCTAssertEqual(transport.vendorWriteCount, 0)
    }

    func testLocalDimmingUsesOfficialTarget() throws {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }

        try controller.setLocalDimming(.medium)
        XCTAssertEqual(transport.vendorWrittenValues[0x99], [5])
        XCTAssertEqual(transport.vendorWrittenValues[0x47], [5])
    }

    func testRefutedRegisterCannotBeWritten() {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }
        XCTAssertThrowsError(
            try controller.writeVendorValue(vcp: VCPCode.Vendor.displayMode, value: 1)
        ) { error in
            XCTAssertEqual(
                error as? MonitorController.Failure,
                .unsupportedRegister(VCPCode.Vendor.displayMode)
            )
        }
        XCTAssertEqual(transport.writeCount, 0)
    }

    func testUnknownRegisterCannotBeWritten() {
        let (controller, transport) = makeController(hdrEnabled: false) { _ in }
        XCTAssertThrowsError(try controller.writeVendorValue(vcp: 0xAB, value: 1))
        XCTAssertEqual(transport.writeCount, 0)
    }

    func testTargetModelFingerprint() {
        let (controller, _) = makeController(hdrEnabled: false) { _ in }
        XCTAssertTrue(controller.descriptor.isTargetModel)

        let other = DisplayDescriptor(
            id: 2, name: "Other", manufacturer: "DEL", productName: "DELL U2720Q",
            vendorNumber: 0x10AC, modelNumber: 0x1234, displaySerial: 0, edidUUID: nil,
            isBuiltin: false, isMain: false, widthPixels: 3840, heightPixels: 2160,
            refreshRate: 60, supportsHDR: false, registryPath: nil
        )
        XCTAssertFalse(other.isTargetModel)
    }

    func testUnconfirmedHDRSwitchStillWaitsAndReportsLateState() {
        let transport = FakeTransport()
        let session = DDCSession(transport: transport)
        let state = HDRState()
        let controller = MonitorController(
            descriptor: makeController(hdrEnabled: false).0.descriptor, session: session,
            hdrControl: .init(
                isEnabled: { _ in state.enabled },
                // macOS applies the change only after the confirm window.
                setEnabled: { enabled, _ in state.enabled = enabled; return false }
            ),
            postSwitchSettleSeconds: 0.25
        )

        let start = Date()
        XCTAssertTrue(controller.setSystemHDR(enabled: true))
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.2)
    }

    func testHDRSwitchWaitsForLinkRetrain() {
        let transport = FakeTransport()
        let session = DDCSession(transport: transport)
        let descriptor = DisplayDescriptor(
            id: 1, name: "P275MV PLUS", manufacturer: "LHC", productName: "P275MV PLUS",
            vendorNumber: TitanArmyModel.vendorNumber, modelNumber: TitanArmyModel.modelNumber,
            displaySerial: 0, edidUUID: nil, isBuiltin: false, isMain: true,
            widthPixels: 3840, heightPixels: 2160, refreshRate: 160, supportsHDR: true,
            registryPath: nil
        )
        let controller = MonitorController(
            descriptor: descriptor, session: session,
            hdrControl: .init(isEnabled: { _ in false }, setEnabled: { _, _ in true }),
            postSwitchSettleSeconds: 0.25
        )

        let start = Date()
        let changed = controller.setSystemHDR(enabled: true)
        XCTAssertTrue(changed)
        XCTAssertGreaterThanOrEqual(
            Date().timeIntervalSince(start),
            0.2,
            "must wait for the link to re-train before DDC is used again"
        )
    }
}

private final class HDRState: @unchecked Sendable {
    var enabled = false
}
