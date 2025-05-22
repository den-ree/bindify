// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Bindify",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Bindify",
            targets: ["Bindify"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Bindify",
            dependencies: [],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("ImplicitOpenExistentials"),
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "BindifyTests",
            dependencies: ["Bindify"]),
    ]
) 
