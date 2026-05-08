import SwiftUI
import WebKit
import MarkdownRenderer

struct MarkdownWebView: NSViewRepresentable {
    let markdownText: String
    var coordinator: WebViewCoordinator

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        #if DEBUG
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        coordinator.setup(webView: webView)

        if let html = try? MarkdownRenderer.viewerHTMLInlined() {
            webView.loadHTMLString(html, baseURL: nil)
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        coordinator.renderContent(markdownText)
    }
}
