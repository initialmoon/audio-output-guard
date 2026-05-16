// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "audio-output-guard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "audio-output-guard", targets: ["AudioOutputGuard"])
    ],
    targets: [
        .executableTarget(name: "AudioOutputGuard"),
        .testTarget(name: "AudioOutputGuardTests")
    ]
)
