// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PurePetsLayoutKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "PurePetsLayoutKit", targets: ["PurePetsLayoutKit"])
    ],
    targets: [
        .target(
            name: "PurePetsLayoutKit",
            path: "Sources/PurePetsLayoutKit"
        ),
        .testTarget(
            name: "PurePetsLayoutKitTests",
            dependencies: ["PurePetsLayoutKit"],
            path: "Tests/PurePetsLayoutKitTests"
        )
    ]
)
