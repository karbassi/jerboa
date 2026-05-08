# Narrow JS↔Swift bridge: purpose-built handlers, no generic RPC

The JavaScript runtime in the WKWebView communicates with Swift through three named `WKScriptMessageHandler`s, each carrying one specific kind of payload:

- `tocData` — the heading structure that populates the sidebar
- `scrollPosition` — the id of the currently-active heading, for TOC highlighting
- `openLink` — the href of a clicked link, dispatched through `LinkResolver`

We deliberately did not build a generic `{type, payload}` RPC. Each handler exists because Swift can't observe the underlying browser concern (DOM structure, scroll position, link clicks) any other way; if a future feature needs another such observation, it gets its own handler too. Adding a handler should feel like adding a new domain capability, not a new feature toggle — that friction keeps the JS side from quietly accumulating Swift-driven control flow.

Pull-direction calls from Swift to JS go the obvious way: `evaluateJavaScript` against `window.renderMarkdown`, `window.scrollToHeading`, and the font-size functions exposed by `viewer.js`. No bridge is needed because Swift already knows what it wants.
