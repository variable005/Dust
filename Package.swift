// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Dust",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Dust", targets: ["Dust"])
    ],
    targets: [
        .executableTarget(
            name: "Dust",
            path: "Sources/Dust"
        ),
        .testTarget(
            name: "DustTests",
            dependencies: ["Dust"],
            path: "Tests/DustTests"
        )
    ]
)
