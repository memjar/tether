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
        .library(name: "TetherBeam", targets: ["TetherBeam"]),
    ],
    targets: [
        .executableTarget(
            name: "TetherApp",
            dependencies: ["TetherEngine", "TetherAI", "TetherAPI", "TetherBeam"]
        ),
        .target(name: "CDarwinNotify", path: "Sources/CDarwinNotify"),
        .target(name: "TetherEngine", dependencies: ["CDarwinNotify"]),
        .target(name: "TetherAI", dependencies: ["TetherEngine"]),
        .target(name: "TetherAPI", dependencies: ["TetherEngine", "TetherAI"]),
        .target(name: "TetherBeam"),
        .testTarget(name: "TetherEngineTests", dependencies: ["TetherEngine"]),
    ]
)
