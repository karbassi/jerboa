import Cocoa
import MarkdownRenderer
import QuickLookUI
import Rendering
import WebKit

class PreviewViewController: NSViewController, QLPreviewingController {
    private var webView: WKWebView!
    private var renderer: RenderingOrchestrator!

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
        let html = try MarkdownRenderer.viewerHTMLInlined()

        await MainActor.run {
            renderer = RenderingOrchestrator { [weak webView] js in
                webView?.evaluateJavaScript(js)
            }
            webView.navigationDelegate = self
            webView.loadHTMLString(html, baseURL: nil)
            renderer.render(text)
        }
    }

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
        Task { @MainActor in
            renderer?.notePageLoaded()
        }
    }
}
