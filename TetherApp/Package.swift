// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Tether",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "TetherApp", targets: ["TetherApp"]),
    ],
    targets: [
        .target(name: "TetherApp"),
    ]
)
