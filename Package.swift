// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DualShock",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "DualShock", targets: ["DualShock"])],
    targets: [
        .target(name: "ControllerCore"),
        .executableTarget(name: "DualShock", dependencies: ["ControllerCore"]),
        .testTarget(name: "ControllerCoreTests", dependencies: ["ControllerCore"])
    ]
)
