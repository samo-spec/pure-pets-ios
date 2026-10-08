// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HXPHPicker",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "HXPHPicker",
            targets: ["HXPHPicker"]),
        .library(
            name: "HXPhotoPicker",
            targets: ["HXPHPicker"]),
    ],
    targets: [
        .target(
            name: "HXPHPicker",
            path: "Sources/HXPhotoPicker",
            resources: [
                .process("Resources/HXPhotoPicker.bundle"),
                .copy("Resources/PrivacyInfo.xcprivacy")
            ],
            swiftSettings: [
                .define("HXPICKER_ENABLE_SPM"),
                .define("HXPICKER_ENABLE_PICKER"),
                .define("HXPICKER_ENABLE_EDITOR"),
                .define("HXPICKER_ENABLE_CAMERA")
            ]),
    ]
)
