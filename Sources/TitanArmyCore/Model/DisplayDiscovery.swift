import AppKit
import CoreGraphics
import Darwin
import Foundation
import IOKit

public enum DisplayDiscovery {
    /// Lists online displays with EDID identity resolved from the registry.
    public static func onlineDisplays() -> [DisplayDescriptor] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.map { describe($0) }
    }

    public static func describe(_ id: CGDirectDisplayID) -> DisplayDescriptor {
        let path = registryPath(for: id)
        let attrs = path.map(displayAttributes(atRegistryPath:)) ?? [:]
        let product = attrs["ProductAttributes"] as? [String: Any] ?? [:]
        let mode = CGDisplayCopyDisplayMode(id)

        let productName = (product["ProductName"] as? String)
            ?? (attrs["ProductName"] as? String)
            ?? ""

        return DisplayDescriptor(
            id: id,
            name: localizedName(for: id) ?? productName,
            manufacturer: product["ManufacturerID"] as? String ?? "",
            productName: productName,
            vendorNumber: CGDisplayVendorNumber(id),
            modelNumber: CGDisplayModelNumber(id),
            displaySerial: CGDisplaySerialNumber(id),
            edidUUID: attrs["EDID UUID"] as? String,
            isBuiltin: CGDisplayIsBuiltin(id) != 0,
            isMain: CGDisplayIsMain(id) != 0,
            widthPixels: mode?.pixelWidth ?? 0,
            heightPixels: mode?.pixelHeight ?? 0,
            refreshRate: mode?.refreshRate ?? 0,
            supportsHDR: CoreDisplayHDR.advertisesHDR(attrs),
            registryPath: path
        )
    }

    static func localizedName(for id: CGDirectDisplayID) -> String? {
        NSScreen.screens.first { ($0.deviceDescription[.init("NSScreenNumber")] as? NSNumber)?.uint32Value == id }?
            .localizedName
    }

    /// `DisplayAttributes` dictionary for a display, via its registry entry.
    static func displayAttributes(for id: CGDirectDisplayID) -> [String: Any] {
        registryPath(for: id).map(displayAttributes(atRegistryPath:)) ?? [:]
    }

    private static func displayAttributes(atRegistryPath path: String) -> [String: Any] {
        let entry = IORegistryEntryCopyFromPath(kIOMainPortDefault, path as CFString)
        guard entry != 0 else { return [:] }
        defer { IOObjectRelease(entry) }
        return searchProperty(entry, key: "DisplayAttributes") as? [String: Any] ?? [:]
    }

    static func registryPath(for id: CGDirectDisplayID) -> String? {
        guard let info = displayInfoDictionary(for: id) else { return nil }
        return info["IODisplayLocation"] as? String
    }

    static func displayInfoDictionary(for id: CGDirectDisplayID) -> [String: Any]? {
        typealias InfoFn = @convention(c) (CGDirectDisplayID) -> Unmanaged<CFDictionary>?
        guard let handle = CoreDisplayHDR.library,
              let symbol = dlsym(handle, "CoreDisplay_DisplayCreateInfoDictionary") else {
            return nil
        }
        let fn = unsafeBitCast(symbol, to: InfoFn.self)
        return fn(id)?.takeRetainedValue() as? [String: Any]
    }

    /// Recursive registry property lookup (macOS stores display data above the
    /// framebuffer node, not on it).
    static func searchProperty(_ entry: io_registry_entry_t, key: String) -> Any? {
        IORegistryEntrySearchCFProperty(
            entry, kIOServicePlane, key as CFString, kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateRecursively)
        )
    }
}
