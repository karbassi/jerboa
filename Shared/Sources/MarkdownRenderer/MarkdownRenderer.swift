import Foundation

public enum MarkdownRenderer {
    /// Returns the contents of viewer.html from the bundle
    public static func viewerHTML() throws -> String {
        guard let url = Bundle.module.url(forResource: "viewer", withExtension: "html") else {
            throw RendererError.resourceNotFound("viewer.html")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Returns the file URL of viewer.html for loading in WKWebView
    public static func viewerHTMLURL() -> URL? {
        Bundle.module.url(forResource: "viewer", withExtension: "html")
    }

    /// Returns the URL of the Resources directory for WKWebView base URL
    public static func resourceDirectoryURL() -> URL? {
        viewerHTMLURL()?.deletingLastPathComponent()
    }

    /// Returns viewer.html with all stylesheet/script subresources inlined.
    /// Used by WKWebView to avoid per-subresource NetworkProcess scheduling
    /// stalls observed in macOS 26 sandbox profiles.
    public static func viewerHTMLInlined() throws -> String {
        let html = try viewerHTML()
        var output = html
        for match in linkOrScriptMatches(in: html).reversed() {
            guard let resource = try? loadResource(named: match.href) else { continue }
            let replacement = match.isScript
                ? "<script>\n\(resource)\n</script>"
                : "<style>\n\(resource)\n</style>"
            output.replaceSubrange(match.range, with: replacement)
        }
        return output
    }

    private struct ResourceMatch {
        let range: Range<String.Index>
        let href: String
        let isScript: Bool
    }

    private static func linkOrScriptMatches(in html: String) -> [ResourceMatch] {
        var matches: [ResourceMatch] = []
        let patterns: [(NSRegularExpression, Bool)] = [
            (try! NSRegularExpression(pattern: #"<link\b[^>]*\bhref="([^"]+)"[^>]*>"#), false),
            (try! NSRegularExpression(pattern: #"<script\b[^>]*\bsrc="([^"]+)"[^>]*>\s*</script>"#), true),
        ]
        let nsHTML = html as NSString
        for (regex, isScript) in patterns {
            let range = NSRange(location: 0, length: nsHTML.length)
            regex.enumerateMatches(in: html, range: range) { result, _, _ in
                guard let result, result.numberOfRanges == 2,
                      let full = Range(result.range, in: html),
                      let href = Range(result.range(at: 1), in: html) else { return }
                matches.append(ResourceMatch(range: full, href: String(html[href]), isScript: isScript))
            }
        }
        return matches.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    private static func loadResource(named name: String) throws -> String {
        let nsName = name as NSString
        let stem = nsName.deletingPathExtension
        let ext = nsName.pathExtension
        guard let url = Bundle.module.url(forResource: stem, withExtension: ext) else {
            throw RendererError.resourceNotFound(name)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Escapes a string for safe use inside a JS template literal.
    ///
    /// Prefer `Rendering.RenderingOrchestrator` for routine use — it handles escaping
    /// internally as part of the render pipeline. This entry point is exposed for callers
    /// that need to compose JS expressions outside that pipeline.
    public static func escapeForTemplateLiteral(_ string: String) -> String {
        var utf8 = Array(string.utf8)
        var i = utf8.count - 1
        while i >= 0 {
            let byte = utf8[i]
            if byte == 0x5C { // backslash
                utf8.insert(0x5C, at: i)
            } else if byte == 0x60 { // backtick
                utf8.insert(0x5C, at: i)
            } else if byte == 0x24 { // dollar
                utf8.insert(0x5C, at: i)
            }
            i -= 1
        }
        return String(bytes: utf8, encoding: .utf8) ?? string
    }

    public enum RendererError: Error, LocalizedError {
        case resourceNotFound(String)

        public var errorDescription: String? {
            switch self {
            case .resourceNotFound(let name):
                return "Resource not found: \(name)"
            }
        }
    }
}
