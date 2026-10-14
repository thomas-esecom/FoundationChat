// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AppleFoundationChat",
    platforms: [.macOS("27.0")],
    products: [
        .executable(name: "AppleFoundationChat", targets: ["AppleFoundationChat"]),
        .executable(name: "FMTerminalLauncher", targets: ["FMTerminalLauncher"]),
    ],
    targets: [
        .target(name: "TerminalCore"),
        .target(name: "DocumentSupport"),
        .target(name: "ChatHistory"),
        .executableTarget(name: "FMTerminalLauncher"),
        .executableTarget(name: "AppleFoundationChat", dependencies: ["TerminalCore", "DocumentSupport", "ChatHistory"]),
        .testTarget(name: "TerminalCoreTests", dependencies: ["TerminalCore"], resources: [.copy("Fixtures")]),
        .testTarget(name: "DocumentSupportTests", dependencies: ["DocumentSupport"]),
        .testTarget(name: "ChatHistoryTests", dependencies: ["ChatHistory"]),
    ]
)
