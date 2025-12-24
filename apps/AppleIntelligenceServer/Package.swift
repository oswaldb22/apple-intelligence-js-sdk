// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppleIntelligenceServer",
    defaultLocalization: "en",
    platforms: [
       .macOS("26")
    ],
    products: [
        .executable(name: "AppleIntelligenceServer", targets: ["AppleIntelligenceServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.100.0"),
    ],
    targets: [
        .executableTarget(
            name: "AppleIntelligenceServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
            ],
            path: "Sources"
        )
    ]
)
