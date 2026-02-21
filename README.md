<p align="center">
  <img src="App/Assets.xcassets/AppIcon.appiconset/icon_512.png" width="256" height="256" alt="Jerboa app icon">
</p>

<h1 align="center">Jerboa</h1>

<p align="center">
  A lightweight, native Markdown viewer for macOS.
</p>

<p align="center">
  <a href="https://github.com/karbassi/jerboa/releases/latest"><img src="https://img.shields.io/github/v/release/karbassi/jerboa" alt="Latest Release"></a>
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue" alt="macOS 14.0+">
  <img src="https://img.shields.io/github/license/karbassi/jerboa" alt="License">
</p>

---

Jerboa is a read-only Markdown viewer built with Swift and SwiftUI. It renders `.md` files with a clean, native-feeling interface — no editor, no bloat. Open a file, read it, done.

## Features

- **CommonMark rendering** with footnotes, task lists, smart typography, and auto-linking
- **YAML frontmatter** displayed as a styled header with title and metadata
- **Table of contents sidebar** with active heading tracking as you scroll
- **Live reload** — file changes on disk are picked up automatically
- **Dark mode** follows your system appearance
- **QuickLook extension** — preview Markdown files in Finder with spacebar
- **Spotlight indexing** — opened files are searchable via Spotlight
- **Font size controls** — <kbd>Cmd</kbd><kbd>+</kbd> / <kbd>Cmd</kbd><kbd>-</kbd> / <kbd>Cmd</kbd><kbd>0</kbd>
- **Footnote tooltips** — hover to read footnotes inline, no jumping to the bottom
- **CLI support** — `jerboa file.md` from your terminal
- **Custom URL scheme** — `jerboa://open?path=/path/to/file.md`

## Install

### Homebrew

```sh
brew install karbassi/tap/jerboa
```

This installs the app to `/Applications` and makes the `jerboa` command available in your terminal.

### Manual

Download `Jerboa.zip` from the [latest release](https://github.com/karbassi/jerboa/releases/latest), unzip, and drag to `/Applications`.

## Usage

**Open a file:**

```sh
jerboa README.md
```

**Open multiple files:**

```sh
jerboa *.md
```

**Open via URL scheme:**

```sh
open "jerboa://open?path=$(pwd)/README.md"
```

Or just double-click any `.md` file if Jerboa is your default Markdown viewer.

### Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| <kbd>Cmd</kbd> <kbd>+</kbd> | Increase font size |
| <kbd>Cmd</kbd> <kbd>-</kbd> | Decrease font size |
| <kbd>Cmd</kbd> <kbd>0</kbd> | Reset font size |

## Build from Source

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) and Xcode 16+.

```sh
make        # generate project + build
make test   # run tests
make run    # build and launch (debug)
```

## License

[MIT](LICENSE)
