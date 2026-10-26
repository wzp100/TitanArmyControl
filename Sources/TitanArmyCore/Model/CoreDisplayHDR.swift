import CoreGraphics
import Darwin
import Foundation

/// HDR state control through CoreDisplay.
///
/// macOS exposes no public HDR toggle. These symbols are private but present and
/// stable on Apple Silicon; both are resolved dynamically so a missing symbol
/// degrades to "unknown" instead of crashing.
///
/// This matters for this monitor specifically: while HDR is engaged the panel
/// reports DDC brightness `100` and silently ignores writes to VCP `0x10`/`0x12`.
/// Brightness control therefore has to know the HDR state.
public enum CoreDisplayHDR {
    public enum Availability: Sendable {
        case available
        case unsupportedSystem
    }

    /// Extra settling time after an HDR switch.
    ///
    /// Switching HDR re-trains the DisplayPort link, and DDC reads fail outright
    /// for several seconds while that happens. Callers wait this long before
    /// concluding that the DDC channel is gone.
    public static let postSwitchSettleSeconds: Double = 6.0

    private typealias GetFn = @convention(c) (CGDirectDisplayID) -> Bool
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Bool) -> Void

    /// Loaded once; also used by `DisplayDiscovery` for the info dictionary.
    static let library: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_NOW
    )

    private static let getSymbol: GetFn? = {
        guard let library, let p = dlsym(library, "CoreDisplay_Display_IsHDRModeEnabled")
        else { return nil }
        return unsafeBitCast(p, to: GetFn.self)
    }()

    private static let setSymbol: SetFn? = {
        guard let library, let p = dlsym(library, "CoreDisplay_Display_SetHDRModeEnabled")
        else { return nil }
        return unsafeBitCast(p, to: SetFn.self)
    }()

    public static var availability: Availability {
        (getSymbol != nil && setSymbol != nil) ? .available : .unsupportedSystem
    }

    public static func isEnabled(_ id: CGDirectDisplayID) -> Bool? {
        getSymbol?(id)
    }

    /// Whether the display advertises HDR (as opposed to whether it is engaged).
    public static func isSupported(_ id: CGDirectDisplayID) -> Bool {
        advertisesHDR(DisplayDiscovery.displayAttributes(for: id))
    }

    static func advertisesHDR(_ attributes: [String: Any]) -> Bool {
        attributes.keys.contains { $0.hasPrefix("SupportsHDR") || $0 == "SupportsPQEOTF" }
    }

    /// Toggles HDR and waits until macOS reports the requested state.
    ///
    /// The switch renegotiates the display mode and can take well over a
    /// second, so the state is polled instead of sampled once; a single early
    /// sample reported "off" while HDR was still turning on.
    @discardableResult
    public static func setEnabled(
        _ enabled: Bool,
        for id: CGDirectDisplayID,
        timeout: Double = 10,
        pollInterval: Double = 0.25
    ) -> Bool {
        guard let setSymbol else { return false }
        guard isEnabled(id) != enabled else { return true }
        setSymbol(id, enabled)
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            Thread.sleep(forTimeInterval: pollInterval)
            if isEnabled(id) == enabled { return true }
        } while Date() < deadline
        return false
    }
}

