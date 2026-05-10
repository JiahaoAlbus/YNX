// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "YNXVisual",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "YNXVisualApp", targets: ["YNXVisualApp"])
    ],
    targets: [
        .executableTarget(
            name: "YNXVisualApp",
            path: "Sources/YNXVisualApp"
        )
    ]
)
