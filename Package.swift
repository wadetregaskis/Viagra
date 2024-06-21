// swift-tools-version: 5.10

import PackageDescription

let enables = ["AccessLevelOnImport",
               "BareSlashRegexLiterals",
               "ConciseMagicFile",
               "DeprecateApplicationMain",
               "DisableOutwardActorInference",
               "DynamicActorIsolation",
               "ExistentialAny",
               "ForwardTrailingClosures",
               //"FullTypedThrows", // Not ready yet, in Swift 6.  https://forums.swift.org/t/where-is-fulltypedthrows/72346/15
               "GlobalConcurrency",
               "ImplicitOpenExistentials",
               "ImportObjcForwardDeclarations",
               "InferSendableFromCaptures",
               "InternalImportsByDefault",
               "IsolatedDefaultValues",
               "StrictConcurrency"]

let settings: [SwiftSetting] = enables.flatMap {
    [.enableUpcomingFeature($0), .enableExperimentalFeature($0)]
}

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
            name: "Viagra",
            swiftSettings: settings),
    ]
)
