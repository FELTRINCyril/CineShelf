// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MediaKit",
    defaultLocalization: "fr",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "MediaKit", targets: ["MediaKit"])
    ],
    dependencies: [
        .package(path: "../CineShelfCore")
    ],
    targets: [
        .target(
            name: "MediaKit",
            dependencies: [.product(name: "CineShelfCore", package: "CineShelfCore")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "MediaKitTests",
            dependencies: ["MediaKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
