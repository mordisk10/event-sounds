// swift-tools-version: 5.9
import PackageDescription

/// `InstakaiCore` holds the gesture state machines, rule engine and generator.
/// It depends on Foundation only, so it builds and tests on any platform —
/// including CI runners without Xcode. The iOS app in `App/` links against it.
let package = Package(
    name: "InstakaiCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "InstakaiCore", targets: ["InstakaiCore"])
    ],
    targets: [
        .target(
            name: "InstakaiCore",
            path: "Sources/InstakaiCore"
        ),
        .testTarget(
            name: "InstakaiCoreTests",
            dependencies: ["InstakaiCore"],
            path: "Tests/InstakaiCoreTests"
        )
    ]
)
