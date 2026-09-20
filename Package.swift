// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "Dependencies",
    dependencies: [
        // AWS SDK 1.7+ requires SwiftPM build plugins, which rules_swift_package_manager
        // does not execute. Keep the highest plugin-free release until that support lands.
        .package(url: "https://github.com/awslabs/aws-sdk-swift", "1.6.100" ..< "1.7.0"),
        .package(url: "https://github.com/smithy-lang/smithy-swift", "0.200.0" ..< "0.201.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2"),
        .package(url: "https://github.com/apple/swift-system.git", from: "1.8.1"),
    ]
)
