// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "SwiftCentrifuge",
    products: [
        .library(name: "SwiftCentrifuge", targets: ["SwiftCentrifuge"]),
    ],
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream", from:"3.0.6"),
        .package(url: "https://github.com/apple/swift-protobuf", from:"1.7.0"),
        .package(url: "https://github.com/apple/swift-logging", from: "1.4.0")
    ],
    targets: [
        .target(
            name: "SwiftCentrifuge",
            dependencies: ["Starscream", "SwiftProtobuf", "Logging"]
        ),
        .testTarget(
            name: "SwiftCentrifugeTests",
            dependencies: ["SwiftCentrifuge"]
        )
    ]
)
