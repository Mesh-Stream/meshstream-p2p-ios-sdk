// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeshStreamKit",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [.library(name: "MeshStreamKit", targets: ["MeshStreamKit"])],
    targets: [
        .binaryTarget(
            name: "MeshStreamKit",
            url: "https://sdk.meshstream.net/apple/1.0.7/MeshStreamKit.zip",
            checksum: "11843fe4eefcf11d2e75b412eb1f2c9dca46c85e3b322cfaf31645d92c846041"
        )
    ]
)
