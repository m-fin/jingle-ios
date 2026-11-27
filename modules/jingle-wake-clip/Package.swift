// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "jingle-wake-clip",
  platforms: [
    .iOS("16.4")
  ],
  products: [
    .library(name: "JingleWakeClip", targets: ["JingleWakeClip"])
  ],
  dependencies: [
    .package(path: "../ExpoModulesCoreHeaders")
  ],
  targets: [
    .target(
      name: "JingleWakeClip",
      dependencies: [
        .product(name: "ExpoModulesCoreHeaders", package: "ExpoModulesCoreHeaders")
      ],
      path: "ios",
      exclude: ["JingleWakeClip.podspec"]
    )
  ],
  swiftLanguageModes: [.v5]
)
