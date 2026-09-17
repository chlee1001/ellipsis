// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "Ellipsis",
    platforms: [.macOS(.v27)],
    targets: [
        .executableTarget(
            name: "Ellipsis",
            path: "Sources/Ellipsis",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
