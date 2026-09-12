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
    dependencies: [
        .package(
            url: "https://github.com/appstefan/highlightswift.git",
            from: "1.1.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "QuickNotes",
            dependencies: [
                .product(name: "HighlightSwift", package: "highlightswift")
            ],
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
