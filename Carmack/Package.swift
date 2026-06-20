// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Carmack",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "CarmackApp", targets: ["CarmackApp"]),
    ],
    targets: [
        .target(name: "CarmackApp"),
    ]
)
