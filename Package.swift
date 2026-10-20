// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeshStreamKit",
    platforms: [.iOS(.v13), .macOS(.v10_14)],
    products: [.library(name: "MeshStreamKit", targets: ["MeshStreamKit"])],
    targets: [
        .binaryTarget(
            name: "MeshStreamKit",
            url: "https://sdk.meshstream.net/apple/1.0.2/MeshStreamKit.zip",
            checksum: "3cc6edd0fd3bbd4f1edc507c5c86d7634d92cb6291f75b777686b03445e51d35"
        )
    ]
)
