// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Tether",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "Tether", targets: ["TetherApp"]),
        .library(name: "TetherEngine", targets: ["TetherEngine"]),
        .library(name: "TetherAI", targets: ["TetherAI"]),
        .library(name: "TetherAPI", targets: ["TetherAPI"]),
    ],
    targets: [
        .executableTarget(
            name: "TetherApp",
            dependencies: ["TetherEngine", "TetherAI", "TetherAPI"]
        ),
        .target(name: "TetherEngine"),
        .target(name: "TetherAI", dependencies: ["TetherEngine"]),
        .target(name: "TetherAPI", dependencies: ["TetherEngine", "TetherAI"]),
        .testTarget(name: "TetherEngineTests", dependencies: ["TetherEngine"]),
    ]
)
