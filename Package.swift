// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ModDependencyGraphKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ModDependencyGraphKit",
            targets: ["ModDependencyGraphKit"],
        ),
    ],
    targets: [
        .target(
            name: "ModDependencyGraphKit",
            resources: [
                .process("Resources"),
            ],
        ),
        .testTarget(
            name: "ModDependencyGraphKitTests",
            dependencies: ["ModDependencyGraphKit"],
        ),
    ],
)
