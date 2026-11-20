// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DynamicIsland",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "DynamicIsland",
            targets: ["DynamicIsland"]
        ),
        .library(
            name: "DynamicIslandCore",
            targets: ["DynamicIslandCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DynamicIslandCore",
            dependencies: [],
            path: "Sources/DynamicIslandCore"
        ),
        .executableTarget(
            name: "DynamicIsland",
            dependencies: ["DynamicIslandCore"],
            path: "Sources/DynamicIsland"
        ),
        .executableTarget(
            name: "TestRunner",
            dependencies: ["DynamicIslandCore"],
            path: "Tests/TestRunner"
        )
    ]
)
