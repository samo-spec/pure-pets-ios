// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "PurePetsEyes",
    defaultLocalization: "ar",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "PurePetsEyes", targets: ["PureLens"]),
        .library(name: "PureLens", targets: ["PureLens"])
    ],
    targets: [
        .target(
            name: "PureLensCore"
        ),
        .target(
            name: "PureLens",
            dependencies: ["PureLensCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PureLensCoreTests",
            dependencies: ["PureLensCore"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
