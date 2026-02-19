import SwiftUI
import WebKit
import MarkdownRenderer

struct MarkdownWebView: NSViewRepresentable {
    let markdownText: String
    let theme: String
    var coordinator: WebViewCoordinator

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        coordinator.setup(webView: webView)

        if let htmlURL = MarkdownRenderer.viewerHTMLURL(),
           let resourceDir = MarkdownRenderer.resourceDirectoryURL() {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: resourceDir)
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        coordinator.renderContent(markdownText, theme: theme)
    }
}
