// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RetroRescue",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RetroRescue", targets: ["RetroRescue"]),
        .library(name: "VaultEngine", targets: ["VaultEngine"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    ],
    targets: [
        // Main app target (SwiftUI)
        .executableTarget(
            name: "RetroRescue",
            dependencies: [
                "VaultEngine",
                .product(name: "Logging", package: "swift-log"),
            ],
            exclude: [
                "Info.plist",
                "RetroRescue.entitlements",
            ]
        ),
        // Vault format: create, open, store, query .retrovault bundles
        .target(
            name: "VaultEngine",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        // Tests
        .testTarget(
            name: "VaultEngineTests",
            dependencies: ["VaultEngine"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
