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
    private var lastRenderedTheme: String?

    func setup(webView: WKWebView) {
        self.webView = webView

        let contentController = webView.configuration.userContentController
        contentController.add(self, name: "tocData")
        contentController.add(self, name: "scrollPosition")

        webView.navigationDelegate = self
    }

    func renderContent(_ text: String, theme: String) {
        let textChanged = text != lastRenderedText
        let themeChanged = theme != lastRenderedTheme

        lastRenderedText = text
        lastRenderedTheme = theme

        guard isPageLoaded, textChanged || themeChanged else { return }

        if textChanged {
            let escaped = escapeForTemplateLiteral(text)
            let js = "window.renderMarkdown(`\(escaped)`); window.setTheme('\(theme)');"
            webView?.evaluateJavaScript(js)
        } else if themeChanged {
            webView?.evaluateJavaScript("window.setTheme('\(theme)');")
        }
    }

    func scrollToHeading(_ id: String) {
        webView?.evaluateJavaScript("window.scrollToHeading('\(id)');")
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

    func setTheme(_ name: String) {
        lastRenderedTheme = name
        webView?.evaluateJavaScript("window.setTheme('\(name)');")
    }

    private func escapeForTemplateLiteral(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
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
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.isPageLoaded = true
            // Render any content that arrived before page load
            if let text = self.lastRenderedText, let theme = self.lastRenderedTheme {
                let escaped = self.escapeForTemplateLiteral(text)
                let js = "window.renderMarkdown(`\(escaped)`); window.setTheme('\(theme)');"
                self.webView?.evaluateJavaScript(js)
            }
        }
    }
}
