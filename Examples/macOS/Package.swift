// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeshStreamKitMacDemo",
    platforms: [.macOS(.v10_14)],
    dependencies: [.package(name: "MeshStreamKit", path: "../..")],
    targets: [
        .executableTarget(
            name: "MeshStreamKitMacDemo",
            dependencies: [.product(name: "MeshStreamKit", package: "MeshStreamKit")],
            path: "Sources",
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("AVKit")]
        )
    ]
)
