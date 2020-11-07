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
    dependencies: [ ],
    targets: [
        .target(name: "OperationLog", dependencies: []),
        .testTarget(name: "OperationLogTests", dependencies: ["OperationLog"]),
    ]
)
