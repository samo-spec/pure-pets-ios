// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "PurePetsAdShareKit",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v17)
  ],
  products: [
    .library(
      name: "PurePetsAdShareKit",
      targets: ["PurePetsAdShareKit"]
    )
  ],
  targets: [
    .target(
      name: "PurePetsAdShareKit",
      path: "Sources/PurePetsAdShareKit",
      resources: [
        .process("Resources")
      ]
    ),
    .testTarget(
      name: "PurePetsAdShareKitTests",
      dependencies: ["PurePetsAdShareKit"],
      path: "Tests/PurePetsAdShareKitTests"
    ),
  ]
)
