// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "SwiftNASR",
    platforms: [
        .macOS(.v10_13), .iOS(.v11), .tvOS(.v11), .watchOS(.v4)
    ],

    products: [
        .library(
            name: "SwiftNASR",
            targets: ["SwiftNASR"]),
        .executable(name: "SwiftNASR_E2E", targets: ["SwiftNASR_E2E"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation/", .branch("development")), // required to get in-memory support
        .package(url: "https://github.com/Quick/Quick.git", .upToNextMajor(from: "2.2.0")),
        .package(url: "https://github.com/Quick/Nimble.git", .branch("master")) // required for Swift 5.3 support
    ],
    targets: [
        .target(
            name: "SwiftNASR",
            dependencies: ["ZIPFoundation",]),
        .testTarget(
            name: "SwiftNASRTests",
            dependencies: ["SwiftNASR", "Quick", "Nimble"]),
        .target(
            name: "SwiftNASR_E2E",
            dependencies: ["SwiftNASR"],
            path: "Tests/SwiftNASR_E2E")
    ],
    swiftLanguageVersions: [.v5]
)
