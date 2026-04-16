// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Lumio",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "Lumio", targets: ["Lumio"]),
    ],
    targets: [
        .target(name: "Lumio"),
        .testTarget(name: "LumioTests", dependencies: ["Lumio"]),
    ]
)
