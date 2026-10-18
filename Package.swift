// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeshStreamKit",
    platforms: [.iOS(.v13), .macOS(.v10_14)],
    products: [.library(name: "MeshStreamKit", targets: ["MeshStreamKit"])],
    targets: [
        .binaryTarget(
            name: "MeshStreamKit",
            url: "https://sdk.meshstream.net/apple/0.1.0/MeshStreamKit-r2.zip",
            checksum: "a6d8889678a5a6f71480bc2cc84d7459f74b449a5c6f5492731ace9536788202"
        )
    ]
)
