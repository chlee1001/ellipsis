// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "Ellipsis",
    platforms: [.macOS(.v27)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "Ellipsis",
            dependencies: ["Sparkle"],
            path: "Sources/Ellipsis",
            swiftSettings: [.swiftLanguageMode(.v6)],
            // bundle.sh puts Sparkle.framework in Contents/Frameworks.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(
            name: "EllipsisTests",
            dependencies: ["Ellipsis"],
            path: "Tests/EllipsisTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
