// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MazesAndBigLizards",
    platforms: [.iOS(.v16), .macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MazesAndBigLizards",
            path: "Sources/MazesAndBigLizards"
        )
    ]
)
