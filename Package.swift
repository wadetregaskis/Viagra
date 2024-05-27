// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Viagra",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .macCatalyst(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "Viagra",
            targets: ["Viagra"]),
    ],
    targets: [
        .target(
            name: "Viagra"),
    ]
)
