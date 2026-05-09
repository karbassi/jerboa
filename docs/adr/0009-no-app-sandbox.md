# Drop the macOS app sandbox

Jerboa's `Jerboa.entitlements` no longer declares `com.apple.security.app-sandbox`. The app runs without the macOS sandbox.

The trigger was #23: every API for opening a sibling Document (`NSDocumentController.openDocument`, `NSWorkspace.shared.open`) hit `NSPOSIXErrorDomain Code=13 "Permission denied"` because `com.apple.security.files.user-selected.read-only` only grants access to the file the Reader explicitly opened, not its siblings. Cross-Document linking — a feature ADR-0001 calls in scope — was structurally broken. The alternatives (an Open dialog with `canChooseDirectories=true` for every cross-Document link, or accepting the limitation and forcing manual re-opens) all carried worse trade-offs than dropping the sandbox.

The read-only invariant is now enforced exclusively in code: `FileWatcher` opens files with `O_EVTONLY`, `MarkdownDocument` exposes no write path, and the renderer is JS-side with no filesystem access. The Content-Security-Policy in `viewer.html` (`default-src 'none'; connect-src 'none';` plus the inline-only allowances from ADR-0003) still blocks crafted Markdown from making outbound network requests. What we lost is the kernel-level defense-in-depth that catches mistakes the code-level enforcement misses; what we gained is cross-Document linking, faster cold start (no per-subresource sandbox-extension stalls — see ADR-0003 for what that fixed), and a simpler entitlements file (now empty).

If Jerboa ever ships through the Mac App Store, the sandbox becomes mandatory and this decision must be revisited — likely with a security-scoped bookmark for the Document's parent directory established at first-open via an explicit "Choose Folder" gesture, persisted as a per-Reader preference. That contradicts ADR-0001's "no persistence beyond OS conventions," so the App Store path implies amending that ADR too.

## What was lost

For a future maintainer wondering whether to put the sandbox back:

1. **Kernel-level fallback if CSP is bypassed.** With `connect-src 'none'` plus a sandbox without `network.client`, even a WebKit CSP-enforcement bug couldn't reach the network. Without sandbox, CSP is the only barrier; a CSP-bypass CVE in WebKit (rare but real) would let crafted Markdown phone home.
2. **Reduced blast radius if WKWebView is exploited.** A WKWebView RCE on a sandboxed Jerboa was limited to files the Reader explicitly opened. Unsandboxed Jerboa exposes the Reader's home directory if the WebView is breached. Both depend on WebKit critical CVEs, so the probability is low; the difference is in worst-case scope.
3. **Mac App Store distribution.** MAS requires the sandbox. The path back implies the directory-bookmark approach above plus an amendment to ADR-0001.
4. **Trust signals in regulated environments.** Some enterprise / security-conscious deployments treat sandboxed apps as more trustworthy; the absence of `com.apple.security.app-sandbox` is a flag in security questionnaires even though notarization still applies.

## What was not lost

- **CSP still defends the document.** `default-src 'none'`, `script-src 'unsafe-inline'`, `style-src 'unsafe-inline'`, `img-src 'self' file: data:`, `connect-src 'none'`, etc. (ADR-0003). Crafted Markdown still cannot make XHR/fetch calls or load remote images.
- **Read-only is enforced in code.** `FileWatcher` opens with `O_EVTONLY`; `MarkdownDocument` exposes no write path; no save flow exists.
- **Notarization still applies.** Distribution still passes through Apple's malware checks.
- **The Reader's own files are safe from the app's normal operation.** Jerboa never writes to disk by design, sandbox or not.

## Net assessment

For a single-user, local, read-only viewer not on MAS, the practical exposure of removing sandbox is small. The two real attack paths (#1 and #2) both require a WebKit critical CVE plus a malicious Markdown file the Reader opens — narrow conjunctions, mostly mitigated by CSP. The cost (broken cross-Document linking, slow cold start) was concrete and present; the protection lost was theoretical and rare.

This is a defensible trade-off for the current product. It is not a defensible trade-off for an App Store release or an enterprise deployment, and either of those paths means restoring the sandbox via the directory-bookmark approach.
