// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pixy",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Pixy", targets: ["Pixy"])
    ],
    targets: [
        .executableTarget(
            name: "Pixy",
            path: "Sources/Pixy"
        )
    ]
)
