# Jerboa

Lightweight, native macOS Markdown viewer. Read-only, no editor. Swift/SwiftUI shell with a WKWebView-backed renderer driven by markdown-it.

## Layout

```
App/                          SwiftUI app target
  JerboaApp.swift             entry point, scene, menu commands, URL scheme
  ContentView.swift           document view, sidebar, file watcher, reload button
  MarkdownWebView.swift       NSViewRepresentable wrapping WKWebView
  WebViewCoordinator.swift    JS bridge, navigation/script handlers, crash recovery
  FileWatcher.swift           DispatchSource-based file change watcher (O_EVTONLY)
  MarkdownDocument.swift      ReferenceFileDocument (read-only)
  SpotlightIndexer.swift      CoreSpotlight indexing for opened files
  TOCSidebarView.swift        table-of-contents sidebar
  DebugScreenshot.swift       SIGUSR1 → window PNG + state JSON sidecar (DEBUG only)
  Jerboa.entitlements         empty (sandbox dropped — see ADR-0009)
  Info.plist                  bundle metadata, document types, URL scheme

Shared/                                  Swift package — testable via `swift test`
  Sources/MarkdownRenderer/              viewer.html, viewer.js, *.css, markdown-it bundles, Heading struct, escape helper, viewerHTMLInlined()
  Sources/DocumentSync/                  FileWatcher + Reading | Pending Reload | Missing state machine (ADR-0007)
  Sources/Linking/                       LinkResolver + LinkActionDispatching (resolve href → execute action)
  Sources/Rendering/                     RenderingOrchestrator + ScriptMessageParser (queue render, decode bridge messages)
  Sources/JerboaCLI/                     Pure CLI argv parser (--help, file paths, dashed-flag pairs)
  Tests/                                 one test target per module; 80 tests, all green via swift test

Tests/JerboaTests/             XCTest target (RenderBenchmarkTests only — currently dormant; runner won't bootstrap on this macOS)
Tests/JerboaUITests/           XCUITest end-to-end (3 tests; class-level shared launch + accessibility-id selectors)
Tests/js/                      vitest tests for viewer.js (103 tests)

QuickLook/                     QuickLook preview extension (.appex), uses RenderingOrchestrator (#22)
docs/agents/                   agent-skill conventions (issue tracker, labels, domain)
docs/adr/                      architecture decision records (0001-0009)
project.yml                    XcodeGen config; .xcodeproj is generated, not checked in
.mise.toml                     dev task runner (build/test/lint/sign/zip)
biome.json                     CSS/JS linter+formatter config
```

## Common tasks

Run via `mise run <task>`. The full list lives in `.mise.toml`; the ones you'll use most:

- `mise run generate` — regenerate `Jerboa.xcodeproj` from `project.yml` (also stamps `BuildConfig/GitInfo.local.xcconfig` with the current git SHA + tag-derived version)
- `mise run build` — build the app
- `mise run debug` / `mise run run` — Debug build / Debug build + launch
- `mise run test-package` — `swift test` in `Shared/` (80 tests, fast, reliable — preferred for unit testing)
- `mise run test-js` — vitest tests for `viewer.js` (103 tests)
- `xcodebuild test -scheme JerboaUITests -destination 'platform=macOS'` — XCUITest end-to-end (3 tests, ~14s; needs Accessibility permission for the test runner on this machine — granted manually via System Settings)
- `mise run test` — full XCTest unit suite (currently dormant; runner won't bootstrap on this macOS for unit tests)
- `mise run lint` / `mise run lint:fix` — Biome on CSS/JS
- `mise run sign` / `mise run zip` / `mise run install` — release packaging

`xcodebuild` works directly too; the `mise` tasks are wrappers with the right scheme/destination/codesign defaults.

## Invariants and gotchas

- **Read-only.** The app never writes the open file. The watcher uses `O_EVTONLY`; `MarkdownDocument` exposes no write path. Don't add code that modifies, renames, or backs up the user's `.md`. Rendered content is a separate `displayText` state to prevent dirty-state side effects.
- **No app sandbox.** `Jerboa.entitlements` is intentionally empty. Read-only is enforced in code; outbound network from rendered Markdown is blocked by CSP. See ADR-0009 for what was lost (kernel-level fallback for CSP-bypass, MAS path) and why the trade-off favours not having it.
- **Viewer subresources are inlined.** `MarkdownRenderer.viewerHTMLInlined()` reads viewer.html and embeds every `<link>`/`<script src>` as `<style>`/`<script>` before `loadHTMLString(_:baseURL: nil)`. This avoids a macOS 26 WebContent↔NetworkProcess XPC stall (~5s per subresource) that made cold launch take 30–60s. Don't switch back to `loadFileURL` with separate subresource fetches (ADR-0003).
- **CSP is intentionally tight.** `default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self' file: data:; connect-src 'none';` — the `'unsafe-inline'` is acceptable because we own the shell HTML; `connect-src 'none'` blocks any outbound XHR/fetch from rendered Markdown. New external dependencies must be inlined, not linked. CSP is the security boundary now that the sandbox is gone.
- **External file changes notify, don't auto-reload.** `FileWatcher.onEvent` is consumed by `DocumentSyncStateMachine` (ADR-0007). When in `pendingReload`, a "New content" button appears in the window toolbar. `File → Reload (⌘R)` is always available when a Document is focused — including in `reading` state for force-refresh.
- **Cross-Document link clicks open in Jerboa.** `SystemLinkActionDispatcher.openDocument` uses `NSWorkspace.shared.open(_:withApplicationAt:configuration:)` with `Bundle.main.bundleURL`, otherwise Launch Services would route Markdown links to whatever app the Reader has set as their default `.md` handler.
- **Version comes from git tags.** `project.yml` sets `MARKETING_VERSION = $(GIT_VERSION)`, which `mise run generate` populates from `git describe --tags`. Don't hardcode a version in `Info.plist` or anywhere else.
- **`.xcodeproj` is generated.** Edit `project.yml` then `mise run generate`. Don't hand-edit the project file.
- **Test-runner flake on this machine.** The `Jerboa` scheme's XCTest unit-test target (`mise run test`) won't bootstrap on macOS 26 — the runner exits with code 0 before connecting. RenderBenchmarkTests is the only file there now and is effectively dormant locally; CI on fresh macos-26 runners doesn't hit it. The XCUITest scheme works once Accessibility permission is granted to the test runner (System Settings → Privacy & Security → Accessibility); CI runners already have it.
- **CI on every push and PR.** `.github/workflows/test.yml` runs four jobs: `swift test` (Shared package), `vitest` (viewer.js), `xcodebuild build` (full app), and `XCUITest` (JerboaUITests). All green on `macos-26` runners; if a job breaks here it'll break in CI.
- **Autonomous UI verification is via the Debug snapshot.** `kill -USR1 $(pgrep -x Jerboa)` (Debug builds only) writes `${TMPDIR}/jerboa-screenshot.png` (window pixels via `cacheDisplay` — no Screen Recording permission needed) and `${TMPDIR}/jerboa-state.json` (TOC entries, sync state, file URL, scroll-tracked active heading). Use the JSON for verifying SwiftUI Lists and other layer-backed views that `cacheDisplay` can't reliably capture.

## Release flow

1. Update `CHANGELOG.md` with a new `## [x.y.z-tag] - YYYY-MM-DD` section.
2. Commit the changelog (`Update changelog for vX.Y.Z`).
3. Tag annotated: `git tag -a vX.Y.Z -m "vX.Y.Z"`.
4. Push commits and tag: `git push origin main && git push origin vX.Y.Z`.
5. `mise run zip` produces a distributable adhoc-signed `.zip`. There's no Developer ID signing; users see a Gatekeeper prompt on first launch and must `xattr -dr com.apple.quarantine` or right-click → Open.

## Conventions

- Commit messages are sentence-form summaries with a body explaining the why; no Conventional Commits prefix. Co-authored trailers stay.
- Push to `origin main` automatically after committing — explicit user direction in this repo.
- Issue tracker, triage labels, and domain docs are formalised under `docs/agents/` — see the next section.
- Don't create `AGENTS.md`; this project uses `CLAUDE.md` as the agent-instructions file.

## Agent skills

### Issue tracker

Issues live in the `karbassi/jerboa` GitHub repo via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical names: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root. Read both before doing architecture work — they record the scope rule, glossary (Reader, Document, Heading, Section, Pending Reload, Missing), and decisions like the sandbox removal, the watcher state machine, the inlined-HTML loading strategy, and the titlebar-indicator primitives. See `docs/agents/domain.md`.
