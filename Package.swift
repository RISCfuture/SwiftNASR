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
        .package(url: "https://github.com/weichsel/ZIPFoundation/", .upToNextMajor(from: "0.9.12")),
        .package(url: "https://github.com/Quick/Quick.git", .upToNextMajor(from: "4.0.0")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "9.2.0"))
    ],
    targets: [
        .target(
            name: "SwiftNASR",
            dependencies: ["ZIPFoundation"]),
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
