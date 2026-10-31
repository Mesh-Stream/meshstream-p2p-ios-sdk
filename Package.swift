// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeshStreamKit",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [.library(name: "MeshStreamKit", targets: ["MeshStreamKit"])],
    targets: [
        .binaryTarget(
            name: "MeshStreamKit",
            url: "https://sdk.meshstream.net/apple/1.0.8/MeshStreamKit.zip",
            checksum: "85a84975e917064a5b602a1cb25380707c3491a8b52b57e0d194bb6786609e62"
        )
    ]
)
