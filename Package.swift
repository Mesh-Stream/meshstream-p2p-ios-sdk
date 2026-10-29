// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeshStreamKit",
    platforms: [.iOS(.v13), .macOS(.v10_14)],
    products: [.library(name: "MeshStreamKit", targets: ["MeshStreamKit"])],
    targets: [
        .binaryTarget(
            name: "MeshStreamKit",
            url: "https://sdk.meshstream.net/apple/1.0.6/MeshStreamKit.zip",
            checksum: "91ad37845751c8b4de0363fba692dd9c9204a1c52bb06243d388fbe4d5c757ea"
        )
    ]
)
