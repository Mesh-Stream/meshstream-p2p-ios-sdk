// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeshStreamKit",
    platforms: [.iOS(.v13), .macOS(.v10_14)],
    products: [.library(name: "MeshStreamKit", targets: ["MeshStreamKit"])],
    targets: [
        .binaryTarget(
            name: "MeshStreamKit",
            url: "https://sdk.meshstream.net/apple/1.0.4/MeshStreamKit.zip",
            checksum: "60b76d24fea0e58cb724b241ca4b1037067ba7ffa850c8d5f794ccf65451c554"
        )
    ]
)
