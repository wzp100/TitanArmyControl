import CoreGraphics
import Foundation
import IOKit

/// A resolved DDC/CI channel to one external display.
public struct DDCEndpoint: Sendable {
    /// I2C chip address used for DDC traffic (`0x37` on Apple Silicon DCP).
    public let chipAddress: UInt32
    /// I2C data/offset address (`0x51` for DDC/CI host).
    public let dataAddress: UInt32
    /// Registry path of the owning `DCPAVServiceProxy`, for diagnostics.
    public let servicePath: String
    public let isMCDP29XX: Bool
}

/// Transport abstraction so the protocol layer never touches IOKit directly.
public protocol DDCTransport: AnyObject, Sendable {
    var endpoint: DDCEndpoint { get }
    func write(_ payload: [UInt8]) -> IOReturn
    func read(count: Int) -> (bytes: [UInt8], status: IOReturn)
}

/// Apple Silicon transport backed by `IOAVService*`.
///
/// Not thread-safe by itself; the session serialises access.
public final class IOAVTransport: DDCTransport, @unchecked Sendable {
    public let endpoint: DDCEndpoint
    private let service: CFTypeRef

    init(service: CFTypeRef, endpoint: DDCEndpoint) {
        self.service = service
        self.endpoint = endpoint
    }

    public func write(_ payload: [UInt8]) -> IOReturn {
        guard !payload.isEmpty else { return kIOReturnBadArgument }
        var buffer = payload
        return IOAVServiceWriteI2C(
            service, endpoint.chipAddress, endpoint.dataAddress,
            &buffer, UInt32(buffer.count)
        )
    }

    public func read(count: Int) -> (bytes: [UInt8], status: IOReturn) {
        var buffer = [UInt8](repeating: 0, count: max(count, 1))
        let status = IOAVServiceReadI2C(
            service, endpoint.chipAddress, endpoint.dataAddress,
            &buffer, UInt32(buffer.count)
        )
        return (buffer, status)
    }
}

/// Builds an `IOAVTransport` for a display discovered through CoreGraphics.
public enum DDCTransportFactory {
    /// DDC chip addresses seen on Apple platforms.
    static let defaultChipAddress: UInt32 = 0x37
    static let mcdp29xxChipAddress: UInt32 = 0xB7
    static let hostDataAddress: UInt32 = 0x51

    /// Resolves the `DCPAVServiceProxy` that belongs to `displayID`.
    ///
    /// The association is made through the display's `IODisplayLocation`, which
    /// points at the framebuffer node. Walking the registry from that node finds
    /// the sibling AV proxy. Using a global "first proxy wins" shortcut is wrong
    /// as soon as two displays are attached.
    public static func makeTransport(for displayID: CGDirectDisplayID) -> IOAVTransport? {
        guard let location = DisplayDiscovery.registryPath(for: displayID) else { return nil }
        let framebuffer = IORegistryEntryCopyFromPath(kIOMainPortDefault, location as CFString)
        guard framebuffer != 0 else { return nil }
        defer { IOObjectRelease(framebuffer) }

        guard let proxy = findAVProxy(forFramebuffer: framebuffer) else { return nil }
        defer { IOObjectRelease(proxy) }

        guard let service = IOAVService.create(from: proxy) else { return nil }

        var path = [CChar](repeating: 0, count: 1024)
        IORegistryEntryGetPath(proxy, kIOServicePlane, &path)
        let proxyPath = String(cString: path)

        let isMCDP = providerClass(of: proxy) == "AppleDCPMCDP29XX"
        let endpoint = DDCEndpoint(
            chipAddress: isMCDP ? mcdp29xxChipAddress : defaultChipAddress,
            dataAddress: hostDataAddress,
            servicePath: proxyPath.isEmpty ? location : proxyPath,
            isMCDP29XX: isMCDP
        )
        return IOAVTransport(service: service, endpoint: endpoint)
    }

    /// Finds the external `DCPAVServiceProxy` belonging to a framebuffer entry.
    ///
    /// The proxy is a sibling of the framebuffer inside the `dcpext` node, so we
    /// walk up from the framebuffer and look for proxies among each ancestor's
    /// children instead of taking whichever proxy the registry happens to list
    /// first (wrong as soon as two displays are attached).
    static func findAVProxy(forFramebuffer framebuffer: io_registry_entry_t) -> io_service_t? {
        var node = framebuffer
        var owned: io_registry_entry_t = 0
        defer { if owned != 0 { IOObjectRelease(owned) } }

        for _ in 0..<6 {
            if let proxy = externalProxyChild(of: node) { return proxy }

            var parent: io_registry_entry_t = 0
            guard IORegistryEntryGetParentEntry(node, kIOServicePlane, &parent) == KERN_SUCCESS,
                  parent != 0 else { break }
            if owned != 0 { IOObjectRelease(owned) }
            owned = parent
            node = parent
        }
        return nil
    }

    /// Returns the first external AV proxy in the subtree below `node`.
    private static func externalProxyChild(of node: io_registry_entry_t) -> io_service_t? {
        var iterator: io_iterator_t = 0
        guard IORegistryEntryCreateIterator(
            node, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator
        ) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            if IOObjectConformsTo(entry, "DCPAVServiceProxy") != 0 {
                let location = IORegistryEntryCreateCFProperty(
                    entry, "Location" as CFString, kCFAllocatorDefault, 0
                )?.takeRetainedValue() as? String
                if location == "External" { return entry }
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        return nil
    }

    static func providerClass(of service: io_service_t) -> String? {
        var parent: io_registry_entry_t = 0
        guard IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent) == KERN_SUCCESS
        else { return nil }
        defer { IOObjectRelease(parent) }
        guard let value = IORegistryEntryCreateCFProperty(
            parent, "EPICProviderClass" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? String else { return nil }
        return value
    }
}
