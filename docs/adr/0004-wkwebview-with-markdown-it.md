# Render Markdown in a WKWebView, parsed by markdown-it with html: true

Documents are rendered by handing JavaScript-side markdown-it the raw text and letting it produce HTML inside a WKWebView. We chose this over SwiftUI's AttributedString rendering (with swift-markdown) and over Swift-side cmark-gfm-then-inject because the JS path is the only one that gives the features Jerboa actually wants — footnote hover tooltips, scroll-tracked TOC, collapsible Sections, GFM alerts/task-lists/footnotes — without rebuilding each one ourselves.

markdown-it is initialised with `html: true` so that real-world Markdown (kbd, details, span styling, inline images with attributes) renders correctly. The cost of allowing raw HTML is moved to a tight Content-Security-Policy in `viewer.html` (`default-src 'none'; connect-src 'none'; …`) — the parser is permissive, the document boundary is restrictive. This is the right place to enforce safety because the threat is exfiltration via crafted Markdown, not the HTML markup itself.

Plugin set is deliberately narrow: footnote, task-lists, github-alerts. Adding others (math, mermaid, syntax highlighting) is allowed only if they meet the scope rule (ADR-0001) and can be loaded without breaking the inlined-HTML model (ADR-0003).
