// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "iPhoneBatteryMenu",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "iPhoneBatteryMenu"
        ),
        .testTarget(
            name: "iPhoneBatteryMenuTests",
            dependencies: ["iPhoneBatteryMenu"]
        )
    ]
)
