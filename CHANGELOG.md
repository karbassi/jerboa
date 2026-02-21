# Changelog

## [1.0.0] - 2026-02-20

First release.

### Features

- **Markdown rendering** — CommonMark via markdown-it with footnotes, task lists, smart typography, and auto-linking
- **YAML frontmatter** — parsed and displayed as a styled header with title, confidential badge, and metadata table
- **Table of contents sidebar** — h2/h3 headings with active heading tracking and scroll-to navigation
- **Live reload** — file changes on disk detected automatically via GCD file watcher with 100ms debounce
- **Dark mode** — full light/dark theme following system appearance
- **QuickLook extension** — preview Markdown files in Finder with spacebar
- **Spotlight indexing** — opened files indexed for system-wide search
- **Font size controls** — increase, decrease, and reset via keyboard shortcuts
- **Footnote tooltips** — hover to read footnotes inline instead of jumping to the bottom
- **CLI support** — `jerboa file.md` from the terminal, with single-instance delegation
- **Custom URL scheme** — `jerboa://open?path=/path/to/file.md`
- **Homebrew cask** — `brew install karbassi/tap/jerboa`

### Performance

- 92 KB document renders in ~19 ms (62% faster than initial prototype)
- JS payload: 129 KB (markdown-it + plugins)
- App size: ~2.5 MB

### Technical

- Swift 6 / SwiftUI with WKWebView rendering
- App sandbox with read-only file access
- XcodeGen-based project generation
- GitHub Actions release workflow with Homebrew tap auto-update
