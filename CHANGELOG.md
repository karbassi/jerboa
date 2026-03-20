# Changelog

## [1.4.0-beta.2] - 2026-03-20

### Features

- **Collapsible headers** — click any h2–h6 heading to collapse or expand its section content
- **Ellipsis indicator** — faint `…` appears between collapsed header and next section; click or press Enter/Space to expand
- **Clickable ellipsis** — the `…` indicator is interactive with full keyboard and accessibility support (`role=button`, `aria-label`, `tabindex`)

### Fixed

- **Link-only headings** — headings composed entirely of a link can now be collapsed
- **h4–h6 heading IDs** — all subheadings now get IDs for `scrollToHeading` support, not just h2/h3
- **Var closure bug** — ellipsis click handlers correctly reference their own heading in multi-section documents
- **Text node click safety** — click targets are normalized to Elements before checking for links
- **Checkbox styling** — custom styled checkboxes with proper alignment, checked items dimmed
- **List alignment** — consistent text alignment across checkboxes, bullets, and numbered lists
- **About panel version** — now derived from git tags at build time instead of hardcoded 1.0

### Improved

- **CSS cleanup** — formatted with Biome, removed redundant declarations, fixed specificity ordering
- **Biome linting** — added Biome for CSS/JS/TS linting and formatting with mise tasks
- **h5/h6 heading styles** — added base styles for h5 and h6 headings

## [1.3.0] - 2026-03-18

### Features

- **Collapsible headers** — click any h2/h3/h4 heading to collapse or expand its section content, with a subtle chevron indicator in the left margin

## [1.2.0] - 2026-03-18

### Fixed

- **Blockquote readability** — blockquote text now uses the primary text color instead of muted, ensuring legible contrast in both light and dark mode
- **Checkbox rendering** — fixed task list checkboxes not rendering correctly in WKWebView
- **Read-only enforcement** — decoupled display text from document binding to prevent any autosave or dirty-state side effects

## [1.1.0] - 2026-03-05

### Features

- **GitHub-style alerts** — render NOTE, TIP, IMPORTANT, WARNING, and CAUTION blockquotes with styled callout boxes
- **Smart link handling** — file links open in a new Jerboa window, HTTP(S) links open in the default browser
- **Linkify protocol enforcement** — auto-linking now requires explicit `http://` or `https://` to avoid false positives
- **Build version in About panel** — git SHA stamped into the About window for easy version identification
- **Credits panel** — About window now shows acknowledgments for open-source dependencies

### Improved

- **Menu cleanup** — removed Save, Duplicate, Rename, Move, Revert, and Share menus that don't apply to a read-only viewer
- **Security policy** — switched to GitHub private vulnerability reporting

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
