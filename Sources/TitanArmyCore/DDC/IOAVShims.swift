import Foundation
import IOKit

/// Apple Silicon DDC/CI entry points.
///
/// `IOAVService*` are private but long-stable IOKit symbols exported by
/// `/System/Library/Frameworks/IOKit.framework`. They are resolved through the
/// linker here (declared with `@_silgen_name`) rather than through a bridging
/// header so the package stays pure Swift.
@_silgen_name("IOAVServiceCreateWithService")
func IOAVServiceCreateWithService(
    _ allocator: CFAllocator?,
    _ service: io_service_t
) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOAVServiceWriteI2C")
func IOAVServiceWriteI2C(
    _ service: CFTypeRef,
    _ chipAddress: UInt32,
    _ dataAddress: UInt32,
    _ data: UnsafeMutablePointer<UInt8>,
    _ dataSize: UInt32
) -> IOReturn

@_silgen_name("IOAVServiceReadI2C")
func IOAVServiceReadI2C(
    _ service: CFTypeRef,
    _ chipAddress: UInt32,
    _ dataAddress: UInt32,
    _ outputData: UnsafeMutablePointer<UInt8>,
    _ outputDataSize: UInt32
) -> IOReturn

enum IOAVService {
    /// Creates an `IOAVServiceRef` from an `DCPAVServiceProxy` registry entry.
    static func create(from service: io_service_t) -> CFTypeRef? {
        IOAVServiceCreateWithService(kCFAllocatorDefault, service)?.takeRetainedValue()
    }
}
