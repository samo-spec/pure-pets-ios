// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "SpearLivingChatHeader",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v15)
  ],
  products: [
    .library(
      name: "SpearLivingChatHeader",
      targets: ["SpearLivingChatHeader"]
    )
  ],
  targets: [
    .target(
      name: "SpearLivingChatHeader",
      path: "Sources/SpearLivingChatHeader"
    ),
    .testTarget(
      name: "SpearLivingChatHeaderTests",
      dependencies: ["SpearLivingChatHeader"],
      path: "Tests/SpearLivingChatHeaderTests"
    ),
  ]
)
