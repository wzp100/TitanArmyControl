import Foundation

/// Facts measured on the reference Mac and monitor.
///
/// These are not assumptions carried over from the Windows project; each one was
/// observed here. They exist so the UI can state plainly what is known, instead
/// of presenting unverified vendor labels as truth.
public enum HardwareFindings {
    public struct Finding: Identifiable, Sendable {
        public enum Status: String, Sendable {
            case confirmed
            case partial
            case unresolved
        }

        public let id: String
        public let title: String
        public let detail: String
        public let status: Status
    }

    public static let all: [Finding] = [
        Finding(
            id: "link",
            title: "DDC/CI over USB-C DisplayPort Alt Mode",
            detail: "IOAVService channel on dcpext0 works: reads and writes both succeed.",
            status: .confirmed
        ),
        Finding(
            id: "brightness",
            title: "Hardware brightness",
            detail: "VCP 0x10 is writable and verified by read-back once HDR is off.",
            status: .confirmed
        ),
        Finding(
            id: "hdr-lock",
            title: "HDR freezes the tone registers",
            detail: "With HDR on the panel pins brightness to 100 and ignores 0x10/0x12 writes; turning HDR off revealed 50.",
            status: .confirmed
        ),
        Finding(
            id: "overdrive",
            title: "Overdrive 0-4",
            detail: "VCP 0xE1 accepts every level from Off to 4 and reads back correctly.",
            status: .confirmed
        ),
        Finding(
            id: "picture-mode",
            title: "Picture modes 0 and 3-14",
            detail: "VCP 0xE0 rejects 1 and 2; all other values up to 14 are accepted.",
            status: .partial
        ),
        Finding(
            id: "vendor-hdr",
            title: "Vendor HDR register mapping",
            detail: "VCP 0xE2 reports a 0-1 range here, so the reference's 0/1/2/3 Off/Auto/Game/Movie table is not confirmed.",
            status: .unresolved
        ),
        Finding(
            id: "screen-mode",
            title: "Dual Mode / Screen Mode selector",
            detail: "No VCP could be confirmed to switch dual mode. VCP 0x3A is not readable at all, so the Windows '25-inch Wide' label cannot be reproduced.",
            status: .unresolved
        ),
        Finding(
            id: "adaptive-sync",
            title: "Adaptive-Sync",
            detail: "The official utility exposes a vendor toggle at 0x99/0xE4 in addition to link-level VRR negotiation. The macOS DDC path cannot read its private state.",
            status: .unresolved
        ),
        Finding(
            id: "official-call-sites",
            title: "Official call-site controls",
            detail: "Gamma, Game Rush, output range and five enhancement sliders were traced to official utility call sites. Their targets are inferred to be authoritative, but picture effects are not verified on this Mac.",
            status: .partial
        ),
    ]
}
