// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeshStreamKit",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [.library(name: "MeshStreamKit", targets: ["MeshStreamKit"])],
    targets: [
        .binaryTarget(
            name: "MeshStreamKit",
            url: "https://sdk.meshstream.net/apple/1.1.0/MeshStreamKit.zip",
            checksum: "2d06b0af34e887ff43232144c5cc10858c00d2ca339c5226a195140aa2d0fb46"
        )
    ]
)
