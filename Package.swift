// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpendyTime",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SpendyTime", targets: ["SpendyTimeApp"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SpendyTimeApp",
            dependencies: [],
            path: "Sources/SpendyTimeApp",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
