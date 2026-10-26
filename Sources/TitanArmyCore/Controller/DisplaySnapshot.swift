import Foundation

/// A point-in-time reading of the monitor.
public struct DisplaySnapshot: Sendable {
    public init() {}

    public struct Reading: Sendable, Equatable {
        public let value: Int
        public let maximum: Int
        public let available: Bool
        public let error: String?

        public init(value: Int, maximum: Int, available: Bool, error: String?) {
            self.value = value
            self.maximum = maximum
            self.available = available
            self.error = error
        }

        public var fraction: Double {
            maximum > 0 ? min(max(Double(value) / Double(maximum), 0), 1) : 0
        }

        public static let unavailable = Reading(value: 0, maximum: 0, available: false, error: nil)
    }

    public var brightness = Reading.unavailable
    public var contrast = Reading.unavailable
    public var gamma = Reading.unavailable
    public var redGain = Reading.unavailable
    public var greenGain = Reading.unavailable
    public var blueGain = Reading.unavailable
    public var volume = Reading.unavailable
    public var muted = Reading.unavailable
    public var inputSource = Reading.unavailable
    public var usageTime = Reading.unavailable
    public var pictureMode = Reading.unavailable
    public var overdrive = Reading.unavailable
    public var screenMode = Reading.unavailable
    public var vendorHDR = Reading.unavailable

    /// `nil` when the system does not expose an HDR query.
    public var hdrEnabled: Bool?
    /// `true` when brightness/contrast writes will be ignored by firmware.
    public var brightnessLockedByHDR: Bool { hdrEnabled == true }

    public var timestamp = Date()
}

extension DDCSession {
    /// Builds a snapshot using best-effort reads; failures never abort the pass.
    public func snapshot(hdrEnabled: Bool?, thorough: Bool = false) -> DisplaySnapshot {
        var snap = DisplaySnapshot()
        snap.hdrEnabled = hdrEnabled

        func reading(_ vcp: UInt8) -> DisplaySnapshot.Reading {
            do {
                let reply = try read(vcp)
                return .init(
                    value: reply.current,
                    maximum: max(reply.maximum, 1),
                    available: true,
                    error: nil
                )
            } catch {
                return .init(
                    value: 0, maximum: 0, available: false,
                    error: (error as? LocalizedError)?.errorDescription ?? "\(error)"
                )
            }
        }

        snap.brightness = reading(VCPCode.brightness)
        snap.contrast = reading(VCPCode.contrast)
        snap.volume = reading(VCPCode.volume)
        snap.muted = reading(VCPCode.mute)

        if thorough {
            snap.gamma = reading(VCPCode.gamma)
            snap.redGain = reading(VCPCode.redGain)
            snap.greenGain = reading(VCPCode.greenGain)
            snap.blueGain = reading(VCPCode.blueGain)
            snap.inputSource = reading(VCPCode.inputSource)
            snap.usageTime = reading(VCPCode.displayUsageTime)
            snap.pictureMode = reading(VCPCode.Vendor.pictureMode)
            snap.overdrive = reading(VCPCode.Vendor.overdrive)
            snap.screenMode = reading(VCPCode.Vendor.screenMode)
            snap.vendorHDR = reading(VCPCode.Vendor.hdrMode)
        }
        snap.timestamp = Date()
        return snap
    }
}
