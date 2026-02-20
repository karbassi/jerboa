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

    /// Escapes a string for safe use inside a JS template literal.
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
