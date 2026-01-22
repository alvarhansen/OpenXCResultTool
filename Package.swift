// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var targets: [Target] = []
var coreDependencies: [Target.Dependency] = [
    .target(name: "SQLite3", condition: .when(platforms: [.linux])),
    .target(name: "SQLite3WASI", condition: .when(platforms: [.wasi])),
    .product(name: "libzstd", package: "zstd")
]

targets.append(
    .systemLibrary(
        name: "SQLite3",
        pkgConfig: "sqlite3",
        providers: [
            .apt(["libsqlite3-dev"])
        ]
    )
)

targets.append(
    .target(
        name: "SQLite3WASI",
        path: "Sources/SQLite3WASI",
        publicHeadersPath: "include",
        linkerSettings: [
            .unsafeFlags(
                ["-L", "Sources/SQLite3WASI/lib"],
                .when(platforms: [.wasi])
            )
        ]
    )
)

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
    .executableTarget(
        name: "OpenXCResultToolWasm",
        dependencies: [
            .target(name: "OpenXCResultTool")
        ],
        linkerSettings: [
            .unsafeFlags(
                [
                    "-Xlinker", "--export=openxcresulttool_alloc",
                    "-Xlinker", "--export=openxcresulttool_free",
                    "-Xlinker", "--export=openxcresulttool_last_error",
                    "-Xlinker", "--export=openxcresulttool_get_test_results_summary_json",
                    "-Xlinker", "--export=openxcresulttool_get_test_results_tests_json",
                    "-Xlinker", "--export=openxcresulttool_get_test_results_test_details_json",
                    "-Xlinker", "--export=openxcresulttool_get_test_results_activities_json",
                    "-Xlinker", "--export=openxcresulttool_get_test_results_metrics_json",
                    "-Xlinker", "--export=openxcresulttool_get_test_results_insights_json",
                    "-Xlinker", "--export=openxcresulttool_sqlite_smoke_test_json",
                    "-Xlinker", "--export=openxcresulttool_register_database",
                    "-Xlinker", "--export=openxcresulttool_version_json",
                    "-Xlinker", "--export=openxcresulttool_get_metadata_json",
                    "-Xlinker", "--export=openxcresulttool_format_description_json",
                    "-Xlinker", "--export=openxcresulttool_graph_text",
                    "-Xlinker", "--export=openxcresulttool_get_object_json",
                    "-Xlinker", "--export=openxcresulttool_compare_json",
                    "-Xlinker", "--export=openxcresulttool_export_diagnostics",
                    "-Xlinker", "--export=openxcresulttool_export_attachments",
                ],
                .when(platforms: [.wasi])
            )
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
        .executable(name: "openxcresulttool", targets: ["OpenXCResultToolCLI"]),
        .executable(name: "openxcresulttool-wasm", targets: ["OpenXCResultToolWasm"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/facebook/zstd", from: "1.4.7")
    ],
    targets: targets
)
