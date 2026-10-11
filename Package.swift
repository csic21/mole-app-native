// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MoleApp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "MoleApp",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/MoleApp",
            resources: [.process("Resources")],
            linkerSettings: [
                // 开发运行(swift run/test)时 SwiftPM 把 Sparkle.framework 放在可执行文件旁;
                // 打包后的 .app 由 package_app.sh 放到 Contents/Frameworks。两个位置都注册 rpath。
                .unsafeFlags([
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path",
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
                ]),
            ]
        ),
        .testTarget(name: "MoleAppTests", dependencies: ["MoleApp"]),
    ]
)
