// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Dependencies",
    dependencies: [
        .package(url: "https://github.com/awslabs/aws-sdk-swift", from: "1.6.69"),
        .package(url: "https://github.com/smithy-lang/smithy-swift", from: "0.189.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.0"),
        .package(url: "https://github.com/apple/swift-system.git", from: "1.6.4"),
    ]
)
