// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WhiskyCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "WhiskyCore", targets: ["WhiskyCore"]),
    ],
    targets: [
        .target(name: "WhiskyCore"),
        .testTarget(name: "WhiskyCoreTests", dependencies: ["WhiskyCore"]),
    ]
)
