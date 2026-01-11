// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "InsightSampleApp",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(name: "InsightSampleApp", targets: ["InsightSampleApp"])
    ],
    targets: [
        .executableTarget(
            name: "InsightSampleApp"
        ),
        .testTarget(
            name: "InsightSampleAppTests",
            dependencies: ["InsightSampleApp"]
        ),
        .testTarget(
            name: "InsightSampleAppUITests",
            dependencies: ["InsightSampleApp"]
        )
    ]
)
