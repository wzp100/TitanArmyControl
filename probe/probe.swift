import Foundation
import IOKit

typealias IOAVServiceRef = CFTypeRef
@_silgen_name("IOAVServiceCreateWithService")
func IOAVServiceCreateWithService(_ allocator: CFAllocator?, _ service: io_service_t) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOAVServiceWriteI2C")
func IOAVServiceWriteI2C(_ service: CFTypeRef, _ chipAddress: UInt32, _ dataAddress: UInt32, _ data: UnsafeMutablePointer<UInt8>, _ dataSize: UInt32) -> IOReturn
@_silgen_name("IOAVServiceReadI2C")
func IOAVServiceReadI2C(_ service: CFTypeRef, _ chipAddress: UInt32, _ dataAddress: UInt32, _ outputData: UnsafeMutablePointer<UInt8>, _ outputDataSize: UInt32) -> IOReturn

func findAVServices() -> [io_service_t] {
    var results: [io_service_t] = []
    var iter: io_iterator_t = 0
    guard let matching = IOServiceMatching("DCPAVServiceProxy") else { return [] }
    guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS else { return [] }
    defer { IOObjectRelease(iter) }
    var svc = IOIteratorNext(iter)
    while svc != 0 { results.append(svc); svc = IOIteratorNext(iter) }
    return results
}

func checksum(_ b: [UInt8]) -> UInt8 { b.reduce(0) { $0 ^ $1 } }

func ddcWrite(_ av: CFTypeRef, msg: [UInt8]) -> IOReturn {
    var packet = msg + [checksum(msg)]
    return IOAVServiceWriteI2C(av, 0x37, 0x51, &packet, UInt32(packet.count))
}

func ddcRead(_ av: CFTypeRef, vcp: UInt8) -> [UInt8]? {
    let req: [UInt8] = [0x82, 0x01, vcp]
    _ = ddcWrite(av, msg: req)
    usleep(50_000)
    var out = [UInt8](repeating: 0, count: 12)
    let r = IOAVServiceReadI2C(av, 0x37, 0x51, &out, UInt32(out.count))
    guard r == KERN_SUCCESS else { return nil }
    return out
}

print("=== DCPAVServiceProxy nodes ===")
let services = findAVServices()
print("count: \(services.count)")
for (i, svc) in services.enumerated() {
    var loc: Unmanaged<CFTypeRef>?
    var unit: Unmanaged<CFTypeRef>?
    IORegistryEntryCreateCFProperty(svc, "Location" as CFString, kCFAllocatorDefault, 0).map { print("  [\(i)] Location = \($0.takeRetainedValue())") }
    IORegistryEntryCreateCFProperty(svc, "Unit" as CFString, kCFAllocatorDefault, 0).map { print("  [\(i)] Unit = \($0.takeRetainedValue())") }
    guard let av = IOAVServiceCreateWithService(kCFAllocatorDefault, svc)?.takeRetainedValue() else {
        print("  [\(i)] IOAVServiceCreateWithService FAILED"); continue
    }
    for vcp in [UInt8(0x10), 0x12, 0xD6, 0xDF, 0x60] {
        if let resp = ddcRead(av, vcp: vcp) {
            let hex = resp.map { String(format: "%02X", $0) }.joined(separator: " ")
            var note = ""
            // reply: [0]=0x6E src, [1]=len|0x80, [2]=0x02, [3]=result/type, [4]=vcp, [5]=type, [6]=maxhi,[7]=maxlo,[8]=curhi,[9]=curlo,[10]=cksum
            if resp.count >= 11, resp[4] == vcp {
                let maxV = (UInt16(resp[6]) << 8) | UInt16(resp[7])
                let curV = (UInt16(resp[8]) << 8) | UInt16(resp[9])
                note = " => vcp=0x\(String(vcp, radix:16)) max=\(maxV) cur=\(curV) result=\(resp[3])"
            }
            print("  [\(i)] VCP 0x\(String(vcp, radix: 16).uppercased()): \(hex)\(note)")
        } else {
            print("  [\(i)] VCP 0x\(String(vcp, radix: 16).uppercased()): read error")
        }
    }
    IOObjectRelease(svc)
}
