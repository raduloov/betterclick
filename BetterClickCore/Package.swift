// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BetterClickCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BetterClickCore", targets: ["BetterClickCore"]),
    ],
    targets: [
        .target(name: "BetterClickCore"),
        .testTarget(name: "BetterClickCoreTests", dependencies: ["BetterClickCore"]),
    ]
)
