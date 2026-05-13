// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XcodeAssetSync",
    platforms: [.macOS(.v13)],
    dependencies: [
        // Lightweight HTTP server
        .package(url: "https://github.com/httpswift/swifter.git", .upToNextMajor(from: "1.5.0")),
    ],
    targets: [
        .executableTarget(
            name: "XcodeAssetSync",
            dependencies: [
                .product(name: "Swifter", package: "swifter"),
            ],
            path: "Sources/XcodeAssetSync"
        ),
    ]
)
