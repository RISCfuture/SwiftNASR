// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftNASR",
    defaultLocalization: "en",
    platforms: [.macOS(.v13), .iOS(.v16), .watchOS(.v9), .tvOS(.v16)],

    products: [
        .library(
            name: "SwiftNASR",
            targets: ["SwiftNASR"]),
        .executable(name: "SwiftNASR_E2E", targets: ["SwiftNASR_E2E"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.12"),
        .package(url: "https://github.com/Quick/Quick.git", from: "7.6.1"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.3.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SwiftNASR",
            dependencies: ["ZIPFoundation"],
            resources: [.process("Resources")],
            linkerSettings: [.linkedLibrary("swift_Concurrency")]),
        .testTarget(
            name: "SwiftNASRTests",
            dependencies: ["SwiftNASR", "Quick", "Nimble"],
            resources: [
                .copy("Resources/MockDistribution"),
                .copy("Resources/FailingMockDistribution")
            ],
            linkerSettings: [.linkedLibrary("swift_Concurrency")]),
        .executableTarget(
            name: "SwiftNASR_E2E",
            dependencies: ["SwiftNASR"],
            path: "Tests/SwiftNASR_E2E",
            linkerSettings: [.linkedLibrary("swift_Concurrency")]),
    ],
    swiftLanguageVersions: [.v5]
)

