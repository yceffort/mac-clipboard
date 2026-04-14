// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacClipboard",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "MacClipboard",
            targets: ["MacClipboard"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "MacClipboard",
            path: "Sources/MacClipboard"
        ),
        .testTarget(
            name: "MacClipboardTests",
            dependencies: ["MacClipboard"],
            path: "Tests/MacClipboardTests"
        ),
    ]
)
