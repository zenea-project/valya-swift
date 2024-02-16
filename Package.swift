// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "valya-swift",
    platforms: [
        .macOS("13.3")
    ],
    products: [
        .library(name: "valya-swift", targets: ["valya"])
    ],
    dependencies: [
        .package(url: "https://github.com/glasfisch3000/zenea-swift.git", branch: "main"),
        .package(url: "https://github.com/glasfisch3000/fastcdc-swift.git", branch: "main")
    ],
    targets: [
        .target(
            name: "valya",
            dependencies: [
                .product(name: "zenea-swift", package: "zenea-swift"),
                .product(name: "FastCDC", package: "fastcdc-swift")
            ]
        )
    ]
)
