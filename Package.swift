// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OverlayTranslator",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OverlayTranslator", targets: ["OverlayTranslator"])
    ],
    targets: [
        .executableTarget(
            name: "OverlayTranslator",
            path: "Sources"
        ),
        .testTarget(
            name: "OverlayTranslatorTests",
            dependencies: ["OverlayTranslator"],
            path: "Tests"
        )
    ]
)

