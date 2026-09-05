// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuickNotes",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "QuickNotes", targets: ["QuickNotes"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "QuickNotes",
            path: "Sources/QuickNotes",
            resources: []
        ),
        .testTarget(
            name: "QuickNotesTests",
            dependencies: ["QuickNotes"],
            path: "Tests/QuickNotesTests"
        )
    ]
)
