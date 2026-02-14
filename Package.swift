// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "TinyDI",
    platforms: [
        .iOS("13.0"),
        .tvOS("13.0"),
        .macOS("10.15"),
    ],
    products: [
        .library(
            name: "TinyDI",
            targets: ["TinyDI"]
        )
    ],
    targets: [
        .target(
            name: "TinyDI",
            path: "Sources"
        ),
        .testTarget(
            name: "TinyDITests",
            dependencies: ["TinyDI"],
            path: "Tests"
        ),
    ]
)
