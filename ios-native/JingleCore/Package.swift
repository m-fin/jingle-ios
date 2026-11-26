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
        .executable(name: "JingleRender", targets: ["JingleRender"]),
    ],
    targets: [
        .target(name: "JingleCore"),
        .executableTarget(name: "JingleRender", dependencies: ["JingleCore"]),
        .testTarget(name: "JingleCoreTests", dependencies: ["JingleCore"]),
    ]
)
