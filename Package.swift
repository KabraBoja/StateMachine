// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StateMachine",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "StateMachine", targets: ["StateMachine"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "StateMachine",
            path: "src"
        ),
        .testTarget(
            name: "StateMachineTests",
            dependencies: [
                "StateMachine",
            ],
            path: "tests"
        )
    ]
)
