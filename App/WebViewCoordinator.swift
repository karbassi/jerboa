import Linking
import MarkdownRenderer
import Rendering
import WebKit

@MainActor
final class WebViewCoordinator: NSObject, ObservableObject {
    @Published var tocEntries: [Heading] = []
    @Published var activeHeadingID: String?
    @Published var fontSize: CGFloat = 13

    var documentDirectoryURL: URL?

    private var webView: WKWebView?
    private let linkDispatcher: LinkActionDispatching
    private var renderer: RenderingOrchestrator?

    init(linkDispatcher: LinkActionDispatching = SystemLinkActionDispatcher()) {
        self.linkDispatcher = linkDispatcher
        super.init()
    }

    func setup(webView: WKWebView) {
        self.webView = webView
        self.renderer = RenderingOrchestrator { [weak webView] js in
            webView?.evaluateJavaScript(js)
        }

        let contentController = webView.configuration.userContentController
        contentController.add(self, name: "tocData")
        contentController.add(self, name: "scrollPosition")
        contentController.add(self, name: "openLink")

        webView.navigationDelegate = self
    }

    func tearDown() {
        guard let webView else { return }
        let contentController = webView.configuration.userContentController
        contentController.removeScriptMessageHandler(forName: "tocData")
        contentController.removeScriptMessageHandler(forName: "scrollPosition")
        contentController.removeScriptMessageHandler(forName: "openLink")
        webView.navigationDelegate = nil
        self.webView = nil
        self.renderer = nil
    }

    func renderContent(_ text: String) {
        renderer?.render(text)
    }

    func scrollToHeading(_ id: String) {
        let escaped = id.replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "'", with: "\\'")
        webView?.evaluateJavaScript("window.scrollToHeading('\(escaped)');")
    }

    func increaseFontSize() {
        fontSize = min(fontSize + 1, 32)
        webView?.evaluateJavaScript("window.increaseFontSize();")
    }

    func decreaseFontSize() {
        fontSize = max(fontSize - 1, 8)
        webView?.evaluateJavaScript("window.decreaseFontSize();")
    }

    func resetFontSize() {
        fontSize = 13
        webView?.evaluateJavaScript("window.resetFontSize();")
    }

    private func handleOpenLink(_ href: String) {
        let action = LinkResolver.resolve(href, relativeTo: documentDirectoryURL)
        linkDispatcher.execute(action)
    }

}

extension WebViewCoordinator: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        let name = message.name
        let body = message.body
        Task { @MainActor in
            guard let event = ScriptMessageParser.parse(name: name, body: body) else { return }
            switch event {
            case .toc(let entries):       self.tocEntries = entries
            case .scrollPosition(let id): self.activeHeadingID = id
            case .openLink(let href):     self.handleOpenLink(href)
            }
        }
    }
}

extension WebViewCoordinator: WKNavigationDelegate {
    nonisolated func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.navigationType == .other {
            decisionHandler(.allow)
        } else if let url = navigationAction.request.url,
                  url.scheme == "https" || url.scheme == "http" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.cancel)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.renderer?.notePageLoaded()
        }
    }

    nonisolated func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Task { @MainActor in
            self.renderer?.notePageTerminated()
            if let html = try? MarkdownRenderer.viewerHTMLInlined() {
                webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }
}
