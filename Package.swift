// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Taskig",
    platforms: [.iOS("9.0"), .macOS("10.11"), .tvOS("9.0"), .watchOS("3.0")],
    products: [
        .library(name: "Taskig", targets: ["Taskig"])
    ],
    targets: [
        .target(
            name: "Taskig",
            path: "TaskigSource/Base"
        ),
        .testTarget(
            name: "TaskigTests",
            dependencies: ["Taskig"],
            path: "TaskigTests"
        )
    ]
)
