// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SmokeClient",
    platforms: [.macOS(.v13)],
    dependencies: [.package(name: "MoMoSDK", path: "../..")],
    targets: [.executableTarget(name: "SmokeClient", dependencies: [.product(name: "MoMoSDK", package: "MoMoSDK")])]
)
