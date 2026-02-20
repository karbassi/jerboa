import WebKit

struct TOCEntry: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let level: Int
}

@MainActor
final class WebViewCoordinator: NSObject, ObservableObject {
    @Published var tocEntries: [TOCEntry] = []
    @Published var activeHeadingID: String?
    @Published var fontSize: CGFloat = 13

    private var webView: WKWebView?
    private var isPageLoaded = false
    private var lastRenderedText: String?

    func setup(webView: WKWebView) {
        self.webView = webView

        let contentController = webView.configuration.userContentController
        contentController.add(self, name: "tocData")
        contentController.add(self, name: "scrollPosition")

        webView.navigationDelegate = self
    }

    func tearDown() {
        guard let webView else { return }
        let contentController = webView.configuration.userContentController
        contentController.removeScriptMessageHandler(forName: "tocData")
        contentController.removeScriptMessageHandler(forName: "scrollPosition")
        webView.navigationDelegate = nil
        self.webView = nil
    }

    func renderContent(_ text: String) {
        guard text != lastRenderedText else { return }
        lastRenderedText = text

        guard isPageLoaded else { return }

        let escaped = escapeForTemplateLiteral(text)
        let js = "window.renderMarkdown(`\(escaped)`);"
        webView?.evaluateJavaScript(js)
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

    private func escapeForTemplateLiteral(_ string: String) -> String {
        var utf8 = Array(string.utf8)
        var i = utf8.count - 1
        // Walk backwards so insertions don't shift unprocessed indices
        while i >= 0 {
            let byte = utf8[i]
            if byte == 0x5C { // backslash
                utf8.insert(0x5C, at: i)
            } else if byte == 0x60 { // backtick
                utf8[i] = 0x60
                utf8.insert(0x5C, at: i)
            } else if byte == 0x24 { // dollar
                utf8.insert(0x5C, at: i)
            }
            i -= 1
        }
        return String(bytes: utf8, encoding: .utf8) ?? string
    }
}

extension WebViewCoordinator: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        Task { @MainActor in
            switch message.name {
            case "tocData":
                if let jsonString = message.body as? String,
                   let data = jsonString.data(using: .utf8) {
                    let entries = (try? JSONDecoder().decode([TOCEntry].self, from: data)) ?? []
                    self.tocEntries = entries
                }
            case "scrollPosition":
                if let id = message.body as? String {
                    self.activeHeadingID = id.isEmpty ? nil : id
                }
            default:
                break
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
            self.isPageLoaded = true
            if let text = self.lastRenderedText {
                let escaped = self.escapeForTemplateLiteral(text)
                let js = "window.renderMarkdown(`\(escaped)`);"
                self.webView?.evaluateJavaScript(js)
            }
        }
    }
}
