// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeshStreamKit",
    platforms: [.iOS(.v13), .macOS(.v10_14)],
    products: [.library(name: "MeshStreamKit", targets: ["MeshStreamKit"])],
    targets: [
        .binaryTarget(
            name: "MeshStreamKit",
            url: "https://sdk.meshstream.net/apple/1.0.0/MeshStreamKit.zip",
            checksum: "6b658c95b5deabf012719b7f02ff3006c39dbdfab32d9d3b3151761edaf4eac0"
        )
    ]
)
