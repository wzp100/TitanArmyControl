import Foundation
import TitanArmyCore
let displays = DisplayDiscovery.onlineDisplays()
guard let d = displays.first(where: { $0.isTargetModel }), let c = MonitorController.connect(d) else { fatalError("target/channel missing") }
for code: UInt8 in [0x04, 0x10, 0x12, 0x16, 0x18, 0x1a, 0x50, 0x52, 0x84, 0x86, 0x88, 0xb8, 0xc0, 0xe0, 0xe1, 0xe2] {
    let vals = (0..<3).compactMap { _ in try? c.session.read(code) }
    let uniq = Set(vals.map { "\($0.current)/\($0.maximum)" })
    print(String(format: "0x%02X %@", code, uniq.count == 1 ? uniq.first! : vals.map { "\($0.current)/\($0.maximum)" }.joined(separator: " | ")))
}
