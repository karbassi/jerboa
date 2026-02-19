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
        let text = try String(contentsOf: url, encoding: .utf8)
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        guard let htmlURL = MarkdownRenderer.viewerHTMLURL(),
              let resourceDir = MarkdownRenderer.resourceDirectoryURL() else {
            return
        }

        await MainActor.run {
            webView.navigationDelegate = self
        }

        let defaults = UserDefaults(suiteName: "group.com.karbassi.Jerboa")
        let theme = defaults?.string(forKey: "jerboa-theme") ?? "classic"
        let js = "window.renderMarkdown(`\(escaped)`); window.setTheme('\(theme)');"

        await MainActor.run {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: resourceDir)
        }

        // Store the JS to execute after page loads
        pendingJS = js
    }

    private var pendingJS: String?
}

extension PreviewViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let js = pendingJS {
            pendingJS = nil
            webView.evaluateJavaScript(js)
        }
    }
}
