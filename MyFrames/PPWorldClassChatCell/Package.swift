// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PPWorldClassChatCell",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "PPChatCellCore", targets: ["PPChatCellCore"]),
        .library(name: "PPChatCellUI", targets: ["PPChatCellUI"])
    ],
    targets: [
        .target(name: "PPChatCellCore"),
        .target(
            name: "PPChatCellUI",
            dependencies: ["PPChatCellCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "PPChatCellCoreTests", dependencies: ["PPChatCellCore"])
    ]
)
