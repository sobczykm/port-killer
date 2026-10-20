// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PortKiller",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "PortKiller", path: "Sources/PortKiller")
    ]
)
