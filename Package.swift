// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MAMenubar",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "MAMenubarLib",
            targets: ["MAMenubarLib"]
        )
    ],
    targets: [
        .target(
            name: "MAMenubarLib",
            path: "Shared"
        ),
        .executableTarget(
            name: "MAMenubar",
            dependencies: ["MAMenubarLib"],
            path: "App",
            exclude: ["Info.plist", "MAMenubar.entitlements"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "App/Info.plist",
                ])
            ]
        ),
        .executableTarget(
            name: "VerifyConnection",
            dependencies: ["MAMenubarLib"],
            path: "Tools/VerifyConnection"
        ),
        .testTarget(
            name: "MAMenubarTests",
            dependencies: ["MAMenubarLib"],
            path: "MAMenubarTests"
        ),
    ]
)
