# Single MarkdownRenderer package for both the App and the QuickLook extension

`Shared/Sources/MarkdownRenderer` is a Swift package consumed by the main app target and by the `JerboaQuickLook` extension. The bundled `viewer.html`, `viewer.js`, plugin scripts, and CSS are the single source of truth for how a Document gets rendered, regardless of which surface a Reader sees it through.

The hard requirement is visual identity: a Document previewed via QuickLook (spacebar in Finder) must look the same as the same Document opened in the app window. Letting the two surfaces diverge — even temporarily — would mean Markdown that renders correctly in one and broken in the other. Sharing the package is the only way to keep that promise without copy-paste.

Both surfaces also share the inlined-HTML loading strategy from ADR-0003 (`loadHTMLString` against the result of `viewerHTMLInlined()`), so the macOS 26 NetworkProcess stalls don't reappear in QuickLook. New rendering features must work in both surfaces; if a feature can only land in one, that's a sign it doesn't belong in the renderer at all.
