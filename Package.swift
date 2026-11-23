// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Deskflip",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Deskflip",
            path: "Sources/Deskflip"
        ),
    ]
)
