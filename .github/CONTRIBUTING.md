# Contributing to Jerboa

Thanks for your interest in contributing.

## Bug Reports

Open an [issue](https://github.com/karbassi/jerboa/issues) with:

- macOS version
- Steps to reproduce
- Expected vs actual behavior
- A sample `.md` file if relevant

## Pull Requests

1. Fork the repo and create a branch from `main`
2. Run `make test` and `make lint` before submitting
3. Keep changes focused — one fix or feature per PR
4. Follow existing code style (Swift 6, SwiftUI patterns)

## Development Setup

```sh
brew bundle            # install xcodegen + swiftlint
make generate          # create Xcode project
make run               # build and launch (debug)
make test              # run tests
```

## What We're Looking For

- Bug fixes
- Rendering improvements
- Accessibility improvements
- Performance optimizations

## What We're Not Looking For

- Editor functionality — Jerboa is a viewer
- Electron or cross-platform rewrites
- Features that require network access
