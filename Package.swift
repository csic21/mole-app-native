// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MoleApp",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MoleApp",
            path: "Sources/MoleApp",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "MoleAppTests", dependencies: ["MoleApp"]),
    ]
)
