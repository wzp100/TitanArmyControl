// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "TitanArmy",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "TitanArmyCore", targets: ["TitanArmyCore"]),
        .executable(name: "titanarmyctl", targets: ["TitanArmyCLI"]),
        .executable(name: "TitanArmy", targets: ["TitanArmyApp"]),
        .executable(name: "vendorprobe", targets: ["VendorProbe"]),
    ],
    targets: [
        .target(name: "TitanArmyCore"),
        .executableTarget(name: "TitanArmyCLI", dependencies: ["TitanArmyCore"]),
        .executableTarget(name: "ReadProbe", dependencies: ["TitanArmyCore"], path: "Tools/ReadProbe"),
        .executableTarget(name: "TitanArmyApp", dependencies: ["TitanArmyCore"]),
        .executableTarget(name: "VendorProbe", dependencies: ["TitanArmyCore"], path: "Probe", exclude: ["probe", "probe2", "probe.swift", "probe2.swift"]),
        .testTarget(name: "TitanArmyCoreTests", dependencies: ["TitanArmyCore"]),
    ],
    swiftLanguageModes: [.v5]
)
