// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReClipMac",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ReClipMac", targets: ["ReClipMac"])
    ],
    targets: [
        .executableTarget(
            name: "ReClipMac",
            path: "Sources/ReClipMac",
            resources: [.process("Resources")]
        )
    ]
)
