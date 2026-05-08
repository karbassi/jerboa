import Foundation
import MarkdownRenderer

/// Owns the timing of "render this Document text" against a WKWebView's lifecycle.
///
/// The Document's text can arrive at any moment — from initial load, from a Pending Reload
/// being applied, or from the Reader changing windows. The web page may not be ready yet
/// (the viewer.html `loadHTMLString` hasn't finished), or it may have died unexpectedly
/// (WebContent process termination, ADR-0003). The orchestrator buffers the latest text,
/// dedups consecutive identical renders, and re-fires on reload.
///
/// The single side effect — handing a JS expression to a WKWebView — is injected so tests
/// can substitute a recording closure and assert exactly when (and what) JS would have
/// fired without bringing up an actual WebKit instance.
@MainActor
public protocol RenderingOrchestrating {
    func render(_ markdown: String)
    func notePageLoaded()
    func notePageTerminated()
}

@MainActor
public final class RenderingOrchestrator: RenderingOrchestrating {
    private var isPageLoaded = false
    private var lastRenderedText: String?
    private let evaluate: (String) -> Void

    public init(evaluate: @escaping (String) -> Void) {
        self.evaluate = evaluate
    }

    public func render(_ markdown: String) {
        guard markdown != lastRenderedText else { return }
        lastRenderedText = markdown
        guard isPageLoaded else { return }
        fireRender(markdown)
    }

    public func notePageLoaded() {
        isPageLoaded = true
        if let text = lastRenderedText {
            fireRender(text)
        }
    }

    public func notePageTerminated() {
        isPageLoaded = false
    }

    private func fireRender(_ markdown: String) {
        let escaped = MarkdownRenderer.escapeForTemplateLiteral(markdown)
        evaluate("window.renderMarkdown(`\(escaped)`);")
    }
}
