// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JingleCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "JingleCore", targets: ["JingleCore"]),
    ],
    targets: [
        .target(name: "JingleCore"),
        .testTarget(name: "JingleCoreTests", dependencies: ["JingleCore"]),
    ]
)
