# Inline viewer subresources via loadHTMLString

`MarkdownRenderer.viewerHTMLInlined()` reads `viewer.html` and embeds every `<link>` and `<script src>` as `<style>` and `<script>` blocks before handing the result to `WKWebView.loadHTMLString(_:baseURL: nil)`. The viewer is loaded as a single self-contained document with no subresource fetches.

The reason is a macOS 26 WKWebView bug: each subresource request from the WebContent process to the NetworkProcess stalls for ~5 seconds (visible as silent gaps between `URL will be scheduled` and `Resource is being scheduled` in `os_log`). With seven `<link>`/`<script src>` tags, cold start took 30–60s. Inlining eliminates the round trips entirely; cold start drops to <2s.

Consequence: the CSP in `viewer.html` must allow `'unsafe-inline'` for `script-src` and `style-src`, since the inlined content has no same-origin to anchor against. `default-src 'none'` and `connect-src 'none'` compensate. Do not "clean up" the inlining back to separate `<link>`/`<script src>` files unless the macOS WebKit bug is confirmed fixed; the regression is a 30× cold-start slowdown.
