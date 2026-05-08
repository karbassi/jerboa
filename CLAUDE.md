# Jerboa

Lightweight, native macOS Markdown viewer. Read-only, no editor. Swift/SwiftUI shell with a WKWebView-backed renderer driven by markdown-it.

## Layout

```
App/                          SwiftUI app target
  JerboaApp.swift             entry point, scene, menu commands, URL scheme
  ContentView.swift           document view, sidebar, file watcher, reload pill
  MarkdownWebView.swift       NSViewRepresentable wrapping WKWebView
  WebViewCoordinator.swift    JS bridge, navigation/script handlers, crash recovery
  FileWatcher.swift           DispatchSource-based file change watcher
  MarkdownDocument.swift      ReferenceFileDocument (read-only)
  LinkResolver.swift          [[wikilinks]] / relative path resolution
  SpotlightIndexer.swift      CoreSpotlight indexing for opened files
  TOCSidebarView.swift        table-of-contents sidebar
  Jerboa.entitlements         sandbox + network.client (required for WebKit)
  Info.plist                  bundle metadata, document types, URL scheme

Shared/Sources/MarkdownRenderer/   Swift package
  MarkdownRenderer.swift            inlined-HTML helper, escape utilities
  Resources/                        viewer.html, viewer.js, *.css, markdown-it bundles
Shared/Tests/MarkdownRendererTests/ swift test target

Tests/JerboaTests/             XCTest unit tests (FileWatcher, LinkResolver, TOC, render benchmarks)
Tests/JerboaUITests/           XCUITest end-to-end
Tests/js/                      JS tests for viewer.js

QuickLook/                     QuickLook preview extension (.appex)
docs/agents/                   agent-skill conventions (issue tracker, labels, domain)
docs/adr/                      architecture decision records
project.yml                    XcodeGen config; .xcodeproj is generated, not checked in
.mise.toml                     dev task runner (build/test/lint/sign/zip)
biome.json                     CSS/JS linter+formatter config
```

## Common tasks

Run via `mise run <task>`. The full list lives in `.mise.toml`; the ones you'll use most:

- `mise run generate` — regenerate `Jerboa.xcodeproj` from `project.yml` (also stamps `BuildConfig/GitInfo.local.xcconfig` with the current git SHA + tag-derived version)
- `mise run build` — build the app
- `mise run debug` / `mise run run` — Debug build / Debug build + launch
- `mise run test` — full XCTest suite (currently flaky to bootstrap on macOS 26; see Gotchas)
- `mise run test-package` — `swift test` against the `MarkdownRenderer` package only (fast, reliable)
- `mise run test-js` — JS tests for `viewer.js`
- `mise run lint` / `mise run lint:fix` — Biome on CSS/JS
- `mise run sign` / `mise run zip` / `mise run install` — release packaging

`xcodebuild` works directly too; the `mise` tasks are wrappers with the right scheme/destination/codesign defaults.

## Invariants and gotchas

- **Read-only.** The app never writes the open file. The watcher uses `O_EVTONLY`. Don't add code that modifies, renames, or backs up the user's `.md`. `MarkdownDocument` is bound only for SwiftUI; rendered content is a separate `displayText` state to prevent dirty-state side effects.
- **Sandboxed.** `com.apple.security.app-sandbox` + `com.apple.security.files.user-selected.read-only`. WKWebView additionally requires `com.apple.security.network.client` to launch its content process on macOS 26 — outbound network is then blocked at the document level by the strict CSP in `viewer.html`. Don't remove either.
- **Viewer subresources are inlined.** `MarkdownRenderer.viewerHTMLInlined()` reads viewer.html and embeds every `<link>`/`<script src>` as `<style>`/`<script>` before `loadHTMLString(_:baseURL: nil)`. This avoids a macOS 26 WebContent↔NetworkProcess XPC stall (~5s per subresource) that made cold launch take 30–60s. Don't switch back to `loadFileURL` with separate subresource fetches.
- **CSP is intentionally tight.** `default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self' file: data:; connect-src 'none';` — the `'unsafe-inline'` is acceptable because we own the shell HTML; `connect-src 'none'` blocks any outbound XHR/fetch from rendered Markdown. New external dependencies must be inlined, not linked.
- **External file changes notify, don't auto-reload.** `FileWatcher.onChange` flips `hasPendingUpdate = true`; a "New content" button appears in the window toolbar. Clicking it (or ⌘R) calls `reloadFromDisk()` which preserves scroll position via `viewer.js` saving/restoring `window.scrollY` across `renderMarkdown` calls.
- **Version comes from git tags.** `project.yml` sets `MARKETING_VERSION = $(GIT_VERSION)`, which `mise run generate` populates from `git describe --tags`. Don't hardcode a version in `Info.plist` or anywhere else.
- **`.xcodeproj` is generated.** Edit `project.yml` then `mise run generate`. Don't hand-edit the project file.
- **macOS 26 quirks.** WebKit logs a benign-but-loud `<rdar://problem/28724618>` launchservicesd-denial CRASHSTRING in `WebContent` — Safari hits it too; ignore. Real performance issues show up as 5s gaps between WebKit `URL will be scheduled` and `Resource is being scheduled` log lines.
- **Test runner flake.** `mise run test` (full XCTest) currently fails to bootstrap on this machine's macOS 26 + Xcode combo with "test runner exited with code 0 before establishing connection" — this is pre-existing and not caused by app code. `mise run test-package` and `mise run test-js` work reliably.

## Release flow

1. Update `CHANGELOG.md` with a new `## [x.y.z-tag] - YYYY-MM-DD` section.
2. Commit the changelog (`Update changelog for vX.Y.Z`).
3. Tag annotated: `git tag -a vX.Y.Z -m "vX.Y.Z"`.
4. Push commits and tag: `git push origin main && git push origin vX.Y.Z`.
5. `mise run zip` produces a distributable adhoc-signed `.zip`. There's no Developer ID signing; users see a Gatekeeper prompt on first launch and must `xattr -dr com.apple.quarantine` or right-click → Open.

## Conventions

- Commit messages are sentence-form summaries with a body explaining the why; no Conventional Commits prefix. Co-authored trailers stay.
- Issue tracker, triage labels, and domain docs are formalised under `docs/agents/` — see the next section.
- Don't create `AGENTS.md`; this project uses `CLAUDE.md` as the agent-instructions file.

## Agent skills

### Issue tracker

Issues live in the `karbassi/jerboa` GitHub repo via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical names: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root (created lazily by `/grill-with-docs` — absence is fine). See `docs/agents/domain.md`.
