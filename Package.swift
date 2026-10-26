// swift-tools-version: 6.2
import PackageDescription

// The root manifest supports normal Git URL installation. The nested manifest
// remains available for the existing Xcode workspace and local consumers.
var targets: [Target] = [
    .target(name: "MoMoCore", path: "MoMoSDK/Sources/MoMoCore"),
    .target(name: "MoMoCollections", dependencies: ["MoMoCore"], path: "MoMoSDK/Sources/MoMoCollections"),
    .target(name: "MoMoDisbursements", dependencies: ["MoMoCore"], path: "MoMoSDK/Sources/MoMoDisbursements"),
    .target(name: "MoMoRemittance", dependencies: ["MoMoCore", "MoMoDisbursements"], path: "MoMoSDK/Sources/MoMoRemittance"),
    .target(name: "MoMoSDK", dependencies: ["MoMoCore", "MoMoCollections", "MoMoDisbursements", "MoMoRemittance"], path: "MoMoSDK/Sources/MoMoSDK"),
    .testTarget(name: "MoMoSDKTests", dependencies: ["MoMoSDK", "MoMoCore", "MoMoCollections", "MoMoDisbursements", "MoMoRemittance"], path: "MoMoSDK/Tests/MoMoSDKTests"),
]

#if os(macOS)
// Combine is available on Apple platforms, so compile and exercise the actual demo view models on macOS.
targets.append(.target(
    name: "MoMoDemoViewModels",
    dependencies: ["MoMoCore", "MoMoCollections", "MoMoDisbursements"],
    path: "MoMoDemoApp/MoMoDemoApp",
    exclude: [
        "AppDependencyContainer.swift", "Assets.xcassets", "ContentView.swift", "CredentialStorage.swift",
        "DemoConfiguration.swift", "MoMoConfig.swift.template", "MoMoDemoApp.swift", "MoMoLoadingOverlay.swift", "MoMoTheme.swift",
        "SetUpViewModel.swift", "DepositView.swift"
    ],
    sources: ["CheckoutViewModel.swift", "DepositViewModel.swift"]
))
targets.append(.testTarget(
    name: "MoMoDemoViewModelTests",
    dependencies: ["MoMoDemoViewModels", "MoMoCore", "MoMoCollections", "MoMoDisbursements"],
    path: "MoMoDemoApp/Tests"
))
#endif

let package = Package(
    name: "MoMoSDK",
    platforms: [.iOS(.v16), .macOS(.v13), .watchOS(.v8), .tvOS(.v15)],
    products: [
        .library(name: "MoMoSDK", targets: ["MoMoSDK"]),
        .library(name: "MoMoCore", targets: ["MoMoCore"]),
        .library(name: "MoMoCollections", targets: ["MoMoCollections"]),
        .library(name: "MoMoDisbursements", targets: ["MoMoDisbursements"]),
        .library(name: "MoMoRemittance", targets: ["MoMoRemittance"]),
    ],
    targets: targets
)
