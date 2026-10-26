import CoreGraphics
import Foundation

/// Identity of a connected display as reported by macOS and its EDID.
public struct DisplayDescriptor: Identifiable, Equatable, Sendable {
    public let id: CGDirectDisplayID
    public let name: String
    /// EDID manufacturer ID, e.g. `LHC`.
    public let manufacturer: String
    public let productName: String
    public let vendorNumber: UInt32
    public let modelNumber: UInt32
    /// EDID numeric identity reported by CoreGraphics (often 0 on DP links).
    public let displaySerial: UInt32
    public let edidUUID: String?
    public let isBuiltin: Bool
    public let isMain: Bool
    public let widthPixels: Int
    public let heightPixels: Int
    public let refreshRate: Double
    public let supportsHDR: Bool

    /// Registry path of the framebuffer that drives this display.
    public let registryPath: String?

    public var label: String {
        productName.isEmpty ? name : productName
    }

    /// Exact model fingerprint for the monitor this app targets.
    ///
    /// EDID identity and product name must both agree, so a different Titan
    /// Army panel can never silently receive this model's (still partly
    /// unverified) vendor register writes.
    public var isTargetModel: Bool {
        let vendorMatches = vendorNumber == TitanArmyModel.vendorNumber
            || manufacturer.caseInsensitiveCompare(TitanArmyModel.manufacturer) == .orderedSame
        let modelMatches = modelNumber == TitanArmyModel.modelNumber
            || productName.uppercased().hasPrefix(TitanArmyModel.productNamePrefix)
        return vendorMatches && modelMatches
    }
}

/// Known constants for the Titan Army P275MV PLUS (EDID week 17/2025, v1.4).
public enum TitanArmyModel {
    public static let displayName = "Titan Army P275MV PLUS"
    public static let manufacturer = "LHC"
    public static let productNamePrefix = "P275MV"
    /// `CGDisplayVendorNumber` - the EDID PNP ID packed as `0x00000310`.
    public static let vendorNumber: UInt32 = 0x0000_0310
    /// `CGDisplayModelNumber` - EDID product code `0x907D`.
    public static let modelNumber: UInt32 = 0x0000_907D
}
