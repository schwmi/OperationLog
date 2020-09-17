// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "OperationLog",
    platforms: [
       .macOS(.v10_14)
    ],
    products: [
        .library(name: "OperationLog", targets: ["OperationLog"]),
    ],
    dependencies: [
        .package(url: "git@github.com:schwmi/VectorClock.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "OperationLog", dependencies: ["VectorClock"]),
        .testTarget(name: "OperationLogTests", dependencies: ["OperationLog"]),
    ]
)
