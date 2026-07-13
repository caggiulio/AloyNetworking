// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "AloyNetworking",
  products: [
    .library(name: "AloyNetworking", targets: ["AloyNetworking"]),
    .library(name: "AloyNetworkingNIO", targets: ["AloyNetworkingNIO"]),
  ],
  dependencies: [
    .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.0"),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
  ],
  targets: [
    .target(
      name: "AloyNetworking",
      dependencies: [],
      path: "AloyNetworking/"
    ),
    .target(
      name: "AloyNetworkingNIO",
      dependencies: [
        "AloyNetworking",
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "NIOFoundationCompat", package: "swift-nio"),
      ],
      path: "AloyNetworkingNIO/"
    ),
    .testTarget(
      name: "AloyNetworkingTests",
      dependencies: ["AloyNetworking"]
    ),
  ]
)
