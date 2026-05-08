# Scope rule: helps the Reader read THIS Document right now

Jerboa's design test for any feature: does it help the Reader read THIS Document right now? "This" is per-window; "right now" excludes anything that introduces state across sessions, manages multiple Documents, or treats Jerboa as more than a transient lens on one file. Anything that fails the test is out of scope, even if it's a common Markdown-app affordance (recents menu, folder mode, sync, accounts, cross-Document search, "where I left off" persistence).

Consequences worth naming explicitly:

- **Markdown-only.** Plain-text and other formats are not in scope. `App/Info.plist` should not advertise `public.plain-text` in `LSItemContentTypes`.
- **Read-only.** No editing, no autosave, no dirty state. The file watcher uses `O_EVTONLY`; `MarkdownDocument` exists for the SwiftUI binding only.
- **Window-per-Document.** Markdown link clicks open new windows; there is no in-window navigation history. Each window is an independent Reader session with no shared state.
- **No persistence beyond OS conventions.** Window position via `NSWindow` autosave and font size via `@AppStorage` are fine because they're per-Reader preferences, not per-Document state.
