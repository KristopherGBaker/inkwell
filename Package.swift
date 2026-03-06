// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-blog",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "blog", targets: ["BlogCLI"]),
        .library(name: "BlogCore", targets: ["BlogCore"]),
        .library(name: "BlogRenderer", targets: ["BlogRenderer"]),
        .library(name: "BlogThemes", targets: ["BlogThemes"]),
        .library(name: "BlogPlugins", targets: ["BlogPlugins"]),
        .library(name: "BlogPreview", targets: ["BlogPreview"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.110.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.3"),
        .package(url: "https://github.com/swiftlang/swift-cmark.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "BlogCLI",
            dependencies: [
                "BlogCore",
                "BlogPreview",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: "BlogCore",
            dependencies: ["BlogRenderer", "BlogThemes", "BlogPlugins", "Yams"]
        ),
        .target(
            name: "BlogRenderer",
            dependencies: [
                .product(name: "cmark", package: "swift-cmark")
            ]
        ),
        .target(name: "BlogThemes"),
        .target(name: "BlogPlugins"),
        .target(
            name: "BlogPreview",
            dependencies: [
                .product(name: "Vapor", package: "vapor")
            ]
        ),
        .testTarget(name: "BlogPreviewTests", dependencies: ["BlogPreview"]),
        .testTarget(name: "BlogCoreTests", dependencies: ["BlogCore"]),
        .testTarget(name: "BlogRendererTests", dependencies: ["BlogRenderer"]),
        .testTarget(name: "BlogThemesTests", dependencies: ["BlogThemes"]),
        .testTarget(name: "BlogPluginsTests", dependencies: ["BlogPlugins"]),
        .testTarget(name: "BlogCLITests", dependencies: ["BlogCLI", "BlogCore"]),
        .testTarget(name: "IntegrationTests", dependencies: ["BlogCLI", "BlogCore", "BlogRenderer"])
    ]
)
