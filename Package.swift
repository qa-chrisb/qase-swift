// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "qase-swift",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "QaseCore", targets: ["QaseCore"]),
        .library(name: "QaseXCTest", targets: ["QaseXCTest"]),
    ],
    targets: [
        .target(
            name: "QaseCore"
        ),
        .target(
            name: "QaseXCTest",
            dependencies: ["QaseCore"]
        ),
        .testTarget(
            name: "QaseCoreTests",
            dependencies: ["QaseCore"]
        ),
        .testTarget(
            name: "QaseXCTestTests",
            dependencies: ["QaseXCTest"]
        ),
    ]
)
