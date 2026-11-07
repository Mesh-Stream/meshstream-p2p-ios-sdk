// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeshStreamKit",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [.library(name: "MeshStreamKit", targets: ["MeshStreamKit"])],
    targets: [
        .binaryTarget(
            name: "MeshStreamKit",
            url: "https://sdk.meshstream.net/apple/1.0.10/MeshStreamKit.zip",
            checksum: "1f19243273091916cc5877d383e1ec08997938316d9c34bc71e2ff601727f0f9"
        )
    ]
)
