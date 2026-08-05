// swift-tools-version: 6.0
import PackageDescription

var products: [Product] = [
  .library(
    name: "PurePetsMessagingCore",
    targets: ["PurePetsMessagingCore"]
  )
]

var targets: [Target] = [
  .target(
    name: "PurePetsMessagingCore"
  ),
  .testTarget(
    name: "PurePetsMessagingCoreTests",
    dependencies: ["PurePetsMessagingCore"]
  ),
]

#if !os(Linux)
  products.append(
    .library(
      name: "PurePetsMessagingUI",
      targets: ["PurePetsMessagingUI"]
    )
  )

  targets.insert(
    .target(
      name: "PurePetsMessagingUI",
      dependencies: ["PurePetsMessagingCore"]
    ),
    at: 1
  )
#endif

let package = Package(
  name: "PurePetsMessaging",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v17)
  ],
  products: products,
  targets: targets
)
