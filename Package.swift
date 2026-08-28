// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "RokidWirelessProjectionNative",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "RokidNative", targets: ["RokidNative"])
    ],
    targets: [
        .executableTarget(
            name: "RokidNative",
            path: "Sources/RokidNative",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("CoreImage"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("Network")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
