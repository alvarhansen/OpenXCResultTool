// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var targets: [Target] = []
var coreDependencies: [Target.Dependency] = [
    .product(name: "libzstd", package: "zstd")
]

#if os(Linux)
targets.append(
    .systemLibrary(
        name: "SQLite3",
        pkgConfig: "sqlite3",
        providers: [
            .apt(["libsqlite3-dev"])
        ]
    )
)
coreDependencies.insert(.target(name: "SQLite3"), at: 0)
#endif

targets.append(
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
        name: "OpenXCResultTool",
        dependencies: coreDependencies,
        resources: [
            .process("Resources")
        ],
        linkerSettings: [
            .linkedLibrary("sqlite3")
        ]
    )
)

targets.append(
    .executableTarget(
        name: "OpenXCResultToolCLI",
        dependencies: [
            .target(name: "OpenXCResultTool"),
            .product(name: "ArgumentParser", package: "swift-argument-parser")
        ]
    )
)

targets.append(
    .testTarget(
        name: "OpenXCResultToolTests",
        dependencies: ["OpenXCResultTool"]
    )
)

let package = Package(
    name: "OpenXCResultTool",
    products: [
        .library(name: "OpenXCResultTool", targets: ["OpenXCResultTool"]),
        .executable(name: "openxcresulttool", targets: ["OpenXCResultToolCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/facebook/zstd", from: "1.4.7")
    ],
    targets: targets
)
