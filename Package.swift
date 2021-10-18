// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Weather",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13)],
    products: [
        .library(
            name: "Weather",
            targets: ["Weather"]),
    ],
    dependencies: [
        .package(name: "AutomatedFetcher", url: "https://github.com/helsingborg-stad/spm-automated-fetcher", from: "0.1.3")
    ],
    targets: [
        .target(
            name: "Weather",
            dependencies: ["AutomatedFetcher"]),
        .testTarget(
            name: "WeatherTests",
            dependencies: ["Weather"]),
    ]
)
