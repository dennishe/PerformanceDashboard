// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PerformanceDashboard",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "PerformanceDashboard",
            path: "Sources",
            resources: [
                .process("AppIcon.png")
            ],
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"])
            ],
            linkerSettings: [
                .linkedFramework("CoreWLAN"),
                .linkedFramework("IOBluetooth"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__entitlements",
                    "-Xlinker", "PerformanceDashboard.entitlements"
                ])
            ]
        ),
        .testTarget(
            name: "PerformanceDashboardTests",
            dependencies: ["PerformanceDashboard"],
            path: "Tests/PerformanceDashboardTests"
        )
    ]
)
