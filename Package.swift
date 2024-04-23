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
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.3.0"),
        .package(url: "https://github.com/zenea-project/zenea-swift.git", from: "3.0.0"),
        .package(url: "https://github.com/glasfisch3000/fastcdc-swift.git", from: "3.0.0")
    ],
    targets: [
        .target(
            name: "valya",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "zenea-swift", package: "zenea-swift"),
                .product(name: "fastcdc", package: "fastcdc-swift"),
            ],
            path: "./Sources/valya-swift"
        )
    ]
)
