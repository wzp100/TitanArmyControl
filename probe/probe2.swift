import Foundation
import IOKit

@_silgen_name("IOAVServiceCreateWithService")
func IOAVServiceCreateWithService(_ a: CFAllocator?, _ s: io_service_t) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOAVServiceWriteI2C")
func IOAVServiceWriteI2C(_ s: CFTypeRef, _ c: UInt32, _ d: UInt32, _ p: UnsafeMutablePointer<UInt8>, _ n: UInt32) -> IOReturn
@_silgen_name("IOAVServiceReadI2C")
func IOAVServiceReadI2C(_ s: CFTypeRef, _ c: UInt32, _ d: UInt32, _ o: UnsafeMutablePointer<UInt8>, _ n: UInt32) -> IOReturn

func cks(_ b: [UInt8]) -> UInt8 { b.reduce(0) { $0 ^ $1 } }
func wr(_ av: CFTypeRef, _ m: [UInt8]) -> IOReturn {
    var p = m + [cks(m)]; return IOAVServiceWriteI2C(av, 0x37, 0x51, &p, UInt32(p.count))
}
func rd(_ av: CFTypeRef, _ vcp: UInt8) -> [UInt8]? {
    _ = wr(av, [0x82, 0x01, vcp]); usleep(60_000)
    var o = [UInt8](repeating: 0, count: 12)
    return IOAVServiceReadI2C(av, 0x37, 0x51, &o, 12) == KERN_SUCCESS ? o : nil
}

let iterSvc: io_service_t = {
    var it: io_iterator_t = 0
    IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &it)
    return IOIteratorNext(it)
}()
guard let av = IOAVServiceCreateWithService(kCFAllocatorDefault, iterSvc)?.takeRetainedValue() else { exit(1) }

print("=== EDID (chip 0x50) ===")
var edid = [UInt8](repeating: 0, count: 128)
let er = IOAVServiceReadI2C(av, 0x50, 0x00, &edid, 128)
print("read status = \(er)")
if er == KERN_SUCCESS {
    let hex = edid.map { String(format: "%02X", $0) }.joined()
    print("EDID = \(hex)")
    let mfg = (UInt16(edid[8]) << 8) | UInt16(edid[9])
    func dec(_ v: UInt16) -> String {
        var s = ""; var x = v
        for _ in 0..<3 { s = String(UnicodeScalar(UInt8(64 + (x & 0x1F)))) + s; x >>= 5 }
        return s
    }
    print("Manufacturer=\(dec(mfg))  ProductCode=0x\(String(format:"%04X", UInt16(edid[10]) | (UInt16(edid[11]) << 8)))")
    print("Week=\(edid[16]) Year=\(1990 + Int(edid[17])) Version=\(edid[18]).\(edid[19])")
    for i in stride(from: 54, to: 126, by: 18) {
        if edid[i] == 0 && edid[i+1] == 0 && edid[i+2] == 0 && edid[i+3] == 0xFC {
            let name = String(bytes: edid[(i+5)..<(i+18)].filter { $0 != 0x0A }, encoding: .ascii) ?? "?"
            print("MonitorName='\(name)'")
        }
    }
}

print("\n=== Scan all VCPs 0x00-0xFF ===")
var supported: [UInt8] = []
for v in 0...255 {
    guard let r = rd(av, UInt8(v)) else { continue }
    if r.count >= 11, r[4] == UInt8(v), r[3] == 0x00 {
        let mv = (UInt16(r[6]) << 8) | UInt16(r[7])
        let cv = (UInt16(r[8]) << 8) | UInt16(r[9])
        supported.append(UInt8(v))
        print(String(format: "VCP 0x%02X type=%d max=%u cur=%u", v, r[5], mv, cv))
    }
}
print("\nsupported count: \(supported.count)")
print("supported: " + supported.map { String(format: "%02X", $0) }.joined(separator: " "))
