// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MarkdownRenderer",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MarkdownRenderer", targets: ["MarkdownRenderer"])
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
        .testTarget(
            name: "MarkdownRendererTests",
            dependencies: ["MarkdownRenderer"]
        )
    ]
)
