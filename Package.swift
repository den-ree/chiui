// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Chiui",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Chiui",
            targets: ["Chiui"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Chiui",
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
            name: "ChiuiTests",
            dependencies: ["Chiui"]),
    ]
) 
