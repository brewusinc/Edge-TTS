// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "edge-tts",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        .library(
            name: "EdgeTTS",
            targets: ["EdgeTTS"]
        ),
        .executable(
            name: "edge-tts-cli",
            targets: ["EdgeTTSCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.10.0"),
    ],
    targets: [
        // Core Library
        .target(
            name: "EdgeTTS",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto")
            ],
            path: "Sources/EdgeTTS"
        ),
        // Command Line Tool
        .executableTarget(
            name: "EdgeTTSCLI",
            dependencies: [
                "EdgeTTS",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/EdgeTTSCLI",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
    ]
)
