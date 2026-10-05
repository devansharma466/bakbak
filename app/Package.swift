// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Bakbak",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Bakbak", targets: ["Bakbak"])
    ],
    dependencies: [
        // FluidAudio Parakeet ASR — Apache-2.0, on-device Core ML / ANE.
        // Latest checked: v0.17.5 (Oct 2026). Bump after reading changelogs.
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.17.0")
    ],
    targets: [
        .executableTarget(
            name: "Bakbak",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ],
            path: "Sources/Bakbak"
        )
    ]
)
