// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "SwiftNASR",
  defaultLocalization: "en",
  platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],

  products: [
    .library(
      name: "SwiftNASR",
      targets: ["SwiftNASR"]
    ),
    .executable(name: "SwiftNASR_E2E", targets: ["SwiftNASR_E2E"])
  ],
  dependencies: [
    .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
    .package(url: "https://github.com/Quick/Quick.git", from: "7.6.2"),
    .package(url: "https://github.com/Quick/Nimble.git", from: "13.7.1"),
    .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.4.3"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    .package(url: "https://github.com/RISCfuture/StreamingCSV.git", from: "1.1.1")
  ],
  targets: [
    .target(
      name: "SwiftNASR",
      dependencies: ["ZIPFoundation", "StreamingCSV"],
      resources: [.process("Resources")],
      linkerSettings: [.linkedLibrary("swift_Concurrency")]
    ),
    .testTarget(
      name: "SwiftNASRTests",
      dependencies: ["SwiftNASR", "Quick", "Nimble"],
      resources: [
        .copy("Resources/MockDistribution"),
        .copy("Resources/FailingMockDistribution")
      ],
      linkerSettings: [.linkedLibrary("swift_Concurrency")]
    ),
    .executableTarget(
      name: "SwiftNASR_E2E",
      dependencies: [
        "SwiftNASR",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ],
      path: "Tests/SwiftNASR_E2E",
      linkerSettings: [.linkedLibrary("swift_Concurrency")]
    )
  ],
  swiftLanguageModes: [.v5, .v6]
)
