import Foundation
import TitanArmyCore
// Development helper: restores the panel to the state it was found in and prints
// a read-only summary. Never writes outside this explicit restore list.
let displays = DisplayDiscovery.onlineDisplays()
guard let d = displays.first(where: { $0.isTargetModel }), let c = MonitorController.connect(d) else { exit(1) }
let restore: [(UInt8, UInt16, String)] = [
    (0xE2, 0, "vendor HDR off"),
    (0xE0, 0, "picture mode standard"),
    (0xE1, 0, "overdrive off"),
    (0x62, 100, "volume 100"),
]
if CommandLine.arguments.contains("--restore") {
    let hdrWasOn = c.hdrEnabled == true
    if hdrWasOn { print("HDR off for tone restore..."); _ = c.setSystemHDR(enabled: false) }
    for (vcp, value, label) in restore {
        do { _ = try c.session.write(vcp, value: value); print("  restored \(label)") }
        catch { print("  skip \(label): \((error as? LocalizedError)?.errorDescription ?? "")") }
    }
    do { try c.setBrightness(percent: 100); print("  restored brightness 100") } catch { print("  brightness: \(error)") }
    do { try c.setContrast(percent: 50); print("  restored contrast 50") } catch { print("  contrast: \(error)") }
    if hdrWasOn { print("HDR back on..."); _ = c.setSystemHDR(enabled: true) }
}
print("\nFINAL STATE")
print("  HDR       =", c.hdrEnabled.map { $0 ? "ON" : "off" } ?? "?")
for v: UInt8 in [0x10, 0x12, 0x62, 0xE0, 0xE1, 0xE2, 0x60] {
    let vals = (0..<3).compactMap { _ in c.session.probe(v).map { "\($0.current)/\($0.maximum)" } }
    print(String(format: "  0x%02X = %@", v, Set(vals).count == 1 ? vals[0] : vals.joined(separator: " ")))
}
