// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "dl4-conductor",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "dl4",
            path: "Sources/dl4",
            linkerSettings: [.linkedFramework("CoreMIDI")]
        )
    ],
    swiftLanguageModes: [.v5]
)
