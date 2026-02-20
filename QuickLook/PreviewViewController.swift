import Cocoa
import QuickLookUI
import WebKit
import MarkdownRenderer

class PreviewViewController: NSViewController, QLPreviewingController {
    private var webView: WKWebView!

    override func loadView() {
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8)
                      ?? String(data: data, encoding: .isoLatin1) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        let escaped = MarkdownRenderer.escapeForTemplateLiteral(text)

        guard let htmlURL = MarkdownRenderer.viewerHTMLURL(),
              let resourceDir = MarkdownRenderer.resourceDirectoryURL() else {
            throw CocoaError(.fileReadCorruptFile)
        }

        await MainActor.run {
            webView.navigationDelegate = self
        }

        let js = "window.renderMarkdown(`\(escaped)`);"

        await MainActor.run {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: resourceDir)
        }

        pendingJS = js
    }

    private var pendingJS: String?

    deinit {
        webView?.navigationDelegate = nil
    }
}

extension PreviewViewController: WKNavigationDelegate {
    func webView(
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

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let js = pendingJS {
            pendingJS = nil
            webView.evaluateJavaScript(js)
        }
    }
}
