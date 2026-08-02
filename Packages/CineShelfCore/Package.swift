// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CineShelfCore",
    defaultLocalization: "fr",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "CineShelfCore", targets: ["CineShelfCore"])
    ],
    targets: [
        .target(
            name: "CineShelfCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CineShelfCoreTests",
            dependencies: ["CineShelfCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
