// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeshStreamKit",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [.library(name: "MeshStreamKit", targets: ["MeshStreamKit"])],
    targets: [
        .binaryTarget(
            name: "MeshStreamKit",
            url: "https://sdk.meshstream.net/apple/1.1.1/MeshStreamKit.zip",
            checksum: "aff639a81aaecd57ca4713a872331746d703a595e4f2048a91da363d303f076c"
        )
    ]
)
