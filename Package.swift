// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Silenzio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Silenzio", targets: ["Silenzio"])
    ],
    targets: [
        .executableTarget(
            name: "Silenzio",
            path: "Sources/Silenzio",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("Carbon")
            ]
        )
    ]
)
