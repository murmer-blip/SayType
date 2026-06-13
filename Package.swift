// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SayType",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "SayTypeCore", targets: ["SayTypeCore"]),
        .executable(name: "SayType", targets: ["SayTypeApp"]),
    ],
    targets: [
        .target(name: "SayTypeCore"),
        .executableTarget(
            name: "SayTypeApp",
            dependencies: ["SayTypeCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("Speech"),
            ]
        ),
        .executableTarget(
            name: "SayTypeCoreChecks",
            dependencies: ["SayTypeCore"],
            path: "Tests/SayTypeCoreChecks"
        ),
    ]
)
