// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MoMoSDK",
    platforms: [.iOS(.v16), .macOS(.v13), .watchOS(.v8), .tvOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "MoMoSDK", targets: ["MoMoSDK"]),
        .library(name: "MoMoCollections", targets: ["MoMoCollections"]),
        .library(name: "MoMoDisbursements", targets: ["MoMoDisbursements"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(name: "MoMoCore"),
        .target(name: "MoMoCollections", dependencies: ["MoMoCore"]),
        .target(name: "MoMoDisbursements", dependencies: ["MoMoCore"]),
        // umbrella target
        .target(name: "MoMoSDK",dependencies: ["MoMoCollections", "MoMoDisbursements"]),
        
        .testTarget(
            name: "MoMoSDKTests",
            dependencies: ["MoMoSDK"]
        ),
    ]
)
