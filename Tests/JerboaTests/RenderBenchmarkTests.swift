import XCTest
import WebKit
@testable import MarkdownRenderer

@MainActor
final class RenderBenchmarkTests: XCTestCase {

    static let smallDoc = """
    # Hello World

    This is a **small** markdown document with a [link](https://example.com).

    ## Section One

    A paragraph with `inline code` and some text.

    ## Section Two

    - Item one
    - Item two
    - Item three
    """

    static let mediumDoc: String = {
        var text = """
        ---
        title: Medium Benchmark Document
        author: Test
        ---

        # Medium Document\n\n
        """
        for i in 1...20 {
            text += """
            ## Section \(i)

            This is paragraph content for section \(i). It contains **bold**, *italic*,
            and `inline code`. Here is a [link](https://example.com/\(i)) for good measure.

            - List item alpha for section \(i)
            - List item beta for section \(i)
            - List item gamma for section \(i)

            > A blockquote inside section \(i) with some meaningful text
            > that spans multiple lines.

            ```swift
            func example\(i)() -> Int {
                return \(i) * 42
            }
            ```\n\n
            """
        }
        return text
    }()

    static let largeDoc: String = {
        var text = """
        ---
        title: Large Benchmark Document
        author: Test
        date: 2026-01-01
        confidential: true
        ---

        # Large Document\n\n
        """
        for i in 1...100 {
            text += """
            ## Section \(i)

            This is paragraph content for section \(i). It contains **bold**, *italic*,
            and `inline code`. Here is a [link](https://example.com/\(i)) for good measure.
            Additional text to bulk up the content. Lorem ipsum dolor sit amet, consectetur
            adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.

            ### Subsection \(i).1

            - List item alpha for section \(i)
            - List item beta for section \(i)
            - List item gamma for section \(i)
            - List item delta for section \(i)

            > A blockquote inside section \(i) with some meaningful text
            > that spans multiple lines and contains **formatted** content.

            | Column A | Column B | Column C |
            |----------|----------|----------|
            | Cell \(i)a | Cell \(i)b | Cell \(i)c |
            | Data \(i)a | Data \(i)b | Data \(i)c |

            ```swift
            func example\(i)() -> Int {
                let value = \(i) * 42
                return value
            }
            ```

            Here is a footnote reference[^\(i)].

            [^\(i)]: This is footnote \(i) with some explanatory text.\n\n
            """
        }
        return text
    }()

    private func createWebViewAndLoad() async throws -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)

        guard let htmlURL = MarkdownRenderer.viewerHTMLURL(),
              let resourceDir = MarkdownRenderer.resourceDirectoryURL() else {
            throw NSError(domain: "Benchmark", code: 1, userInfo: [NSLocalizedDescriptionKey: "Resources not found"])
        }

        webView.loadFileURL(htmlURL, allowingReadAccessTo: resourceDir)

        for _ in 0..<100 {
            try await Task.sleep(nanoseconds: 50_000_000)
            let ready = try await webView.evaluateJavaScript("typeof window.renderMarkdown === 'function'") as? Bool ?? false
            if ready { return webView }
        }
        throw NSError(domain: "Benchmark", code: 2, userInfo: [NSLocalizedDescriptionKey: "Page did not load in time"])
    }

    private func escapeForTemplateLiteral(_ string: String) -> String {
        var result = ""
        result.reserveCapacity(string.count + string.count / 8)
        for char in string {
            switch char {
            case "\\": result += "\\\\"
            case "`": result += "\\`"
            case "$": result += "\\$"
            default: result.append(char)
            }
        }
        return result
    }

    private func benchmarkRender(webView: WKWebView, markdown: String, iterations: Int = 10) async throws -> [Double] {
        let escaped = escapeForTemplateLiteral(markdown)
        var times: [Double] = []

        for _ in 0..<iterations {
            let js = """
            (function() {
                var start = performance.now();
                window.renderMarkdown(`\(escaped)`);
                var end = performance.now();
                return end - start;
            })();
            """
            let result = try await webView.evaluateJavaScript(js)
            if let ms = result as? Double {
                times.append(ms)
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        return times
    }

    func testBenchmarkAll() async throws {
        let webView = try await createWebViewAndLoad()

        let docs: [(String, String)] = [
            ("small", Self.smallDoc),
            ("medium", Self.mediumDoc),
            ("large", Self.largeDoc),
        ]

        var results: [(name: String, size: Int, times: [Double])] = []

        for (name, doc) in docs {
            let times = try await benchmarkRender(webView: webView, markdown: doc, iterations: 10)
            results.append((name: name, size: doc.utf8.count, times: times))
        }

        print("\n=== BENCHMARK RESULTS ===")
        for r in results {
            let sorted = r.times.sorted()
            let median = sorted[sorted.count / 2]
            let avg = r.times.reduce(0, +) / Double(r.times.count)
            let min = sorted.first!
            let max = sorted.last!
            print("DOC=\(r.name) SIZE=\(r.size) MEDIAN=\(String(format: "%.2f", median))ms AVG=\(String(format: "%.2f", avg))ms MIN=\(String(format: "%.2f", min))ms MAX=\(String(format: "%.2f", max))ms")
        }
        print("=== END BENCHMARK ===\n")
    }
}
