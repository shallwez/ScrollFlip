// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScrollFlip",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ScrollFlip", targets: ["ScrollFlip"])
    ],
    targets: [
        .executableTarget(
            name: "ScrollFlip",
            path: "Sources/ScrollFlip",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
