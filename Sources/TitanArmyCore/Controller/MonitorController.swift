import CoreGraphics
import Foundation

/// High-level operations for one attached monitor.
///
/// `MonitorController` is the only place that knows the HDR interaction rule:
/// brightness and contrast are firmware-locked while HDR is on, so those calls
/// fail fast with an actionable message instead of silently doing nothing.
public final class MonitorController: @unchecked Sendable {
    public enum Failure: Error, LocalizedError, Equatable {
        case noDDCChannel
        case toneLockedByHDR
        case unsupportedRegister(UInt8)
        case unknownPreset(String)
        case valueOutOfRange(TitanArmyProfile.WindowsSetting)

        public var errorDescription: String? {
            switch self {
            case .noDDCChannel:
                return "No DDC/CI channel. Reconnect the monitor over DisplayPort or USB-C."
            case .toneLockedByHDR:
                return "HDR is on. Brightness and contrast are locked by the monitor while HDR is active."
            case let .unsupportedRegister(vcp):
                return String(format: "The display does not expose VCP 0x%02X.", vcp)
            case let .unknownPreset(id):
                return "Unknown preset '\(id)'."
            case let .valueOutOfRange(setting):
                return "The value is outside the official range for '\(setting.rawValue)'."
            }
        }
    }

    public let descriptor: DisplayDescriptor
    public let session: DDCSession
    private let hdrControl: HDRControl
    /// How long to wait after a mode change before touching DDC again.
    private let postSwitchSettleSeconds: Double
    private let lock = NSLock()
    /// Mirrors the utility's UI state because private vendor registers cannot be
    /// reliably read back over this macOS DDC connection.
    ///
    /// Keyed by target register, not by setting: several official settings
    /// share one target (Dynamic OD and Custom Dynamic OD are both `0x49`),
    /// and a write through either one changes what the panel holds.
    private var lastOfficialValue: [UInt8: UInt16] = [:]

    /// Injection seam so tests never touch real hardware.
    public struct HDRControl: Sendable {
        public var isEnabled: @Sendable (CGDirectDisplayID) -> Bool?
        public var setEnabled: @Sendable (Bool, CGDirectDisplayID) -> Bool

        public static let live = HDRControl(
            isEnabled: { CoreDisplayHDR.isEnabled($0) },
            setEnabled: { CoreDisplayHDR.setEnabled($0, for: $1) }
        )
    }

    public init(
        descriptor: DisplayDescriptor,
        session: DDCSession,
        hdrControl: HDRControl = .live,
        postSwitchSettleSeconds: Double = CoreDisplayHDR.postSwitchSettleSeconds
    ) {
        self.descriptor = descriptor
        self.session = session
        self.hdrControl = hdrControl
        self.postSwitchSettleSeconds = postSwitchSettleSeconds
    }

    /// Connects to `descriptor`, returning `nil` when no DDC channel exists.
    public static func connect(
        _ descriptor: DisplayDescriptor,
        hdrControl: HDRControl = .live
    ) -> MonitorController? {
        guard let transport = DDCTransportFactory.makeTransport(for: descriptor.id) else {
            return nil
        }
        return MonitorController(
            descriptor: descriptor,
            session: DDCSession(transport: transport),
            hdrControl: hdrControl
        )
    }

    public var hdrEnabled: Bool? { hdrControl.isEnabled(descriptor.id) }

    public func snapshot(thorough: Bool = false) -> DisplaySnapshot {
        session.snapshot(hdrEnabled: hdrEnabled, thorough: thorough)
    }

    // MARK: - Tone

    public func setBrightness(percent: Int) throws {
        try setTone(VCPCode.brightness, percent: percent)
    }

    public func setContrast(percent: Int) throws {
        try setTone(VCPCode.contrast, percent: percent)
    }

    /// Controls the monitor's own speakers.
    ///
    /// Unlike brightness and contrast, this register remains writable while
    /// HDR is engaged.
    public func setVolume(percent: Int) throws {
        let clamped = min(max(percent, 0), 100)
        let reply = try session.read(VCPCode.volume)
        let target = UInt16((Double(clamped) / 100.0 * Double(reply.maximum)).rounded())
        if Int(target) == reply.current { return }
        // Measured on the P275MV PLUS: absolute writes land in one verified
        // step in both directions (44→51, 51→15, 15→51). The former
        // zero-then-step sequence took ~30 s and audibly muted the speakers.
        try session.write(VCPCode.volume, value: target)
    }

    /// Sets a 0...100 register that does not use the percentage scaling bug
    /// found in the sequential volume register. Windows writes the literal
    /// slider value here, so preserve that compatibility.
    public func setStandardTone(percent: Int, register: ToneRegister) throws {
        guard hdrEnabled != true else { throw Failure.toneLockedByHDR }
        let clamped = min(max(percent, 0), 100)
        try session.write(register.rawValue, value: UInt16(clamped))
    }

    public enum ToneRegister: UInt8 {
        case brightness = 0x10
        case contrast = 0x12
    }

    public func setMuted(_ muted: Bool) throws {
        try session.write(VCPCode.mute, value: muted ? 1 : 0)
    }

    public func setGamma(value: Int) throws {
        guard hdrEnabled != true else { throw Failure.toneLockedByHDR }
        let reply = try session.read(VCPCode.gamma)
        guard value >= 0, value <= reply.maximum else {
            throw DDCError.outOfRange(vcp: VCPCode.gamma, value: value, maximum: reply.maximum)
        }
        try session.write(VCPCode.gamma, value: UInt16(value))
    }

    /// Sets one RGB gain register as a percentage of the reported maximum.
    public func setColorGain(_ channel: ColorChannel, percent: Int) throws {
        guard hdrEnabled != true else { throw Failure.toneLockedByHDR }
        let clamped = min(max(percent, 0), 100)
        let reply = try session.read(channel.vcp)
        let value = UInt16((Double(clamped) / 100 * Double(reply.maximum)).rounded())
        try session.write(channel.vcp, value: value)
    }

    /// Selects an input only when the caller supplied a measured value.
    ///
    /// The mapping of 0x60 is firmware-specific. `knownInputs` deliberately
    /// contains just the current USB-C value measured on this unit; the UI can
    /// still display the raw value without inventing HDMI/DP labels.
    public func setInputSource(_ input: TitanArmyProfile.InputSource) throws {
        let reply = try session.read(VCPCode.inputSource)
        guard input.rawValue <= reply.maximum else {
            throw DDCError.outOfRange(
                vcp: VCPCode.inputSource, value: Int(input.rawValue), maximum: reply.maximum
            )
        }
        try session.write(VCPCode.inputSource, value: input.rawValue)
    }

    public enum ColorChannel: String, CaseIterable, Sendable {
        case red, green, blue

        public var vcp: UInt8 {
            switch self {
            case .red: return VCPCode.redGain
            case .green: return VCPCode.greenGain
            case .blue: return VCPCode.blueGain
            }
        }
    }

    /// Applies a 0...100 percentage to a brightness-class register.
    ///
    /// The register's own maximum is respected so odd panels still work.
    private func setTone(_ vcp: UInt8, percent: Int) throws {
        guard hdrEnabled != true else { throw Failure.toneLockedByHDR }
        let clamped = min(max(percent, 0), 100)
        let reply = try session.read(vcp)
        let scaled = UInt16((Double(clamped) / 100.0 * Double(reply.maximum)).rounded())
        try session.write(vcp, value: scaled)
    }

    // MARK: - HDR

    /// Selects the monitor's official HDR mode through the two-write protocol.
    ///
    /// This is separate from macOS HDR; value semantics come from the utility
    /// table/capture, while picture effects still need on-device confirmation.
    public func setVendorHDR(_ mode: TitanArmyProfile.VendorHDR) throws {
        try sendOfficial(.hdrMode, value: mode.rawValue)
    }

    public func setLocalDimming(_ level: TitanArmyProfile.LocalDimming) throws {
        try sendOfficial(.localDimming, value: level.rawValue)
    }

    /// Selects a monitor-side scene preset using the official two-write
    /// sequence.
    ///
    /// The utility intentionally repeats the command value to `0x99` and the
    /// target code in one serialized session. Unlike the retired app's direct
    /// `0xE0` writes, this is the control path used by its 15-scene page.
    public func setSceneMode(_ mode: TitanArmyProfile.SceneMode) throws {
        try sendOfficial(.sceneMode, value: mode.rawValue)
    }

    public func setColorTemperature(_ temperature: TitanArmyProfile.ColorTemperature) throws {
        try sendOfficial(.colorTemperature, value: temperature.rawValue)
    }

    public func setNightVision(_ level: TitanArmyProfile.NightVisionLevel) throws {
        try sendOfficial(.nightVision, value: level.rawValue)
    }

    public func setDynamicOverdrive(_ level: TitanArmyProfile.DynamicOverdriveLevel) throws {
        try sendOfficial(.dynamicOverdrive, value: level.rawValue)
    }

    public func setDyDsULL(_ level: TitanArmyProfile.DyDsULLLevel) throws {
        try sendOfficial(.dyDsULL, value: level.rawValue)
    }

    public func setSharpness(_ level: TitanArmyProfile.SharpnessLevel) throws {
        try sendOfficial(.sharpness, value: level.rawValue)
    }

    public func setLowBlueLight(_ level: TitanArmyProfile.LowBlueLightLevel) throws {
        try sendOfficial(.lowBlueLight, value: level.rawValue)
    }

    public func setAdaptiveSync(_ enabled: Bool) throws {
        try sendOfficial(.adaptiveSync, value: TitanArmyProfile.Toggle(enabled).rawValue)
    }

    public func setOfficialGamma(_ gamma: TitanArmyProfile.OfficialGamma) throws {
        try sendOfficial(.gamma, value: gamma.rawValue)
    }

    public func setGameRush(_ enabled: Bool) throws {
        try sendOfficial(.gameRush, value: TitanArmyProfile.Toggle(enabled).rawValue)
    }

    public func setEnhancement(_ enhancement: TitanArmyProfile.Enhancement, value: Int) throws {
        let setting = enhancement.windowsSetting
        try sendOfficial(setting, value: checkedValue(value, for: setting))
    }

    public func setRGBOutputRange(_ range: TitanArmyProfile.RGBOutputRange) throws {
        try sendOfficial(.rgbOutputRange, value: range.rawValue)
    }

    /// Selects Custom scene and writes one custom target in official order.
    ///
    /// The scene write comes first because Custom (0x20) enables the panel's
    /// custom-image processing path before the target becomes effective. The
    /// value is validated before either write so a bad value changes nothing.
    public func setCustomScene(_ target: TitanArmyProfile.CustomSceneTarget, value: Int) throws {
        let checked = try checkedValue(value, for: target.windowsSetting)
        try sendOfficial(.sceneMode, value: TitanArmyProfile.SceneMode.custom.rawValue)
        try sendOfficial(target.windowsSetting, value: checked)
    }

    public func setGameAssistant(_ command: TitanArmyProfile.GameAssistant.Command) throws {
        try sendOfficial(command.setting, value: command.value, clearing: command.clearedOverlays)
    }

    /// Engages or disengages macOS HDR.
    ///
    /// - Returns: `true` once the requested state is observed.
    @discardableResult
    public func setSystemHDR(enabled: Bool) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let requestedChange = hdrControl.isEnabled(descriptor.id) != enabled
        let confirmed = hdrControl.setEnabled(enabled, descriptor.id)
        if requestedChange {
            // The link re-trains after any mode change request, confirmed or
            // not yet; DDC is unusable until it settles, so wait before anyone
            // reads a snapshot.
            Thread.sleep(forTimeInterval: postSwitchSettleSeconds)
        }
        return confirmed || hdrControl.isEnabled(descriptor.id) == enabled
    }

    // MARK: - Vendor controls

    public func setOverdrive(_ level: TitanArmyProfile.Overdrive) throws {
        try session.write(VCPCode.Vendor.overdrive, value: level.rawValue)
    }

    /// Applies a setting captured from the retired Windows utility.
    ///
    /// The selector and setting-specific writes intentionally remain in this
    /// serial session. Only typed settings and values reach this point, and the
    /// two-command form is not verified by DDC reads because those registers do
    /// not report their OSD state reliably.
    private func sendOfficial(
        _ setting: TitanArmyProfile.WindowsSetting,
        value: UInt16,
        clearing overlays: [TitanArmyProfile.WindowsSetting] = []
    ) throws {
        lock.lock()
        let unchanged = lastOfficialValue[setting.register] == value
        lock.unlock()
        if unchanged { return }

        try writeOfficialPair(setting, value: value)
        // Official enables unconditionally resend the clear commands, even
        // when its cached state says the other overlay is already off.
        for overlay in overlays {
            try writeOfficialPair(overlay, value: 0)
        }

        lock.lock()
        lastOfficialValue[setting.register] = value
        // A clear is not a user selection. Forgetting it guarantees that the
        // next explicit choice for that overlay is sent, including value 0
        // (for example the refresh-rate overlay's Top Right position).
        for overlay in overlays {
            lastOfficialValue[overlay.register] = nil
        }
        lock.unlock()
        // The monitor's own HDR modes cause a short signal/OSD transition.
        // A conservative pause prevents an immediate follow-up DDC command from
        // being silently discarded.
        Thread.sleep(forTimeInterval: setting.settleSeconds)
    }

    private func writeOfficialPair(_ setting: TitanArmyProfile.WindowsSetting, value: UInt16) throws {
        let bytes = [UInt8(value >> 8), UInt8(value & 0xFF)]
        guard session.writeVendorCommand([0x84, 0x03, setting.selector] + bytes) == KERN_SUCCESS,
              session.writeVendorCommand([0x84, 0x03, setting.register] + bytes, delay: 220_000) == KERN_SUCCESS
        else { throw Failure.noDDCChannel }
    }

    private func checkedValue(_ value: Int, for setting: TitanArmyProfile.WindowsSetting) throws -> UInt16 {
        guard setting.allowedRange.contains(value) else { throw Failure.valueOutOfRange(setting) }
        return UInt16(value)
    }

    /// Clears a remembered official value when the display reconnects or the
    /// user asks for an explicit resend.
    public func resetVendorStateCache() {
        lock.lock()
        lastOfficialValue.removeAll()
        lock.unlock()
    }

    /// Applies a preset, one register at a time, stopping at the first failure.
    ///
    /// Each write is range-checked against the value the panel reports, so a
    /// firmware that uses a different encoding fails loudly instead of silently
    /// accepting a bogus value.
    @discardableResult
    public func apply(_ preset: TitanArmyProfile.Preset) throws -> [UInt8: VCPReply] {
        var results: [UInt8: VCPReply] = [:]
        for vcp in preset.values.keys.sorted() {
            guard let value = preset.values[vcp] else { continue }
            results[vcp] = try session.write(vcp, value: value)
        }
        return results
    }

    public func applyPreset(id: String) throws {
        guard let preset = TitanArmyProfile.preset(id: id) else {
            throw Failure.unknownPreset(id)
        }
        try apply(preset)
    }

    /// Writes an arbitrary vendor register after an explicit safety check.
    ///
    /// Refuses codes that the profile marks as refuted and codes it has never
    /// heard of, so new registers cannot be poked by accident.
    public func writeVendorValue(vcp: UInt8, value: UInt16) throws -> VCPReply {
        guard let register = TitanArmyProfile.register(vcp) else {
            throw Failure.unsupportedRegister(vcp)
        }
        guard register.certainty != .refuted else {
            throw Failure.unsupportedRegister(vcp)
        }
        return try session.write(vcp, value: value)
    }
}
