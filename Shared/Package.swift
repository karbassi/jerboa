// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Shared",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MarkdownRenderer", targets: ["MarkdownRenderer"]),
        .library(name: "DocumentSync", targets: ["DocumentSync"]),
        .library(name: "Linking", targets: ["Linking"]),
        .library(name: "Rendering", targets: ["Rendering"]),
        .library(name: "JerboaCLI", targets: ["JerboaCLI"])
    ],
    targets: [
        .target(
            name: "MarkdownRenderer",
            resources: [
                .copy("Resources/viewer.html"),
                .copy("Resources/base.css"),
                .copy("Resources/modern.css"),
                .copy("Resources/markdown-it.min.js"),
                .copy("Resources/markdown-it-footnote.min.js"),
                .copy("Resources/markdown-it-task-lists.min.js"),
                .copy("Resources/markdown-it-github-alerts.min.js"),
                .copy("Resources/viewer.js")
            ]
        ),
        .target(name: "DocumentSync"),
        .target(name: "Linking"),
        .target(name: "Rendering", dependencies: ["MarkdownRenderer"]),
        .target(name: "JerboaCLI"),
        .testTarget(
            name: "MarkdownRendererTests",
            dependencies: ["MarkdownRenderer"]
        ),
        .testTarget(
            name: "DocumentSyncTests",
            dependencies: ["DocumentSync"]
        ),
        .testTarget(
            name: "LinkingTests",
            dependencies: ["Linking"]
        ),
        .testTarget(
            name: "RenderingTests",
            dependencies: ["Rendering"]
        ),
        .testTarget(
            name: "JerboaCLITests",
            dependencies: ["JerboaCLI"]
        )
    ]
)
