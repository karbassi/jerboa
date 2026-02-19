import Foundation

public enum Theme: String, CaseIterable, Sendable {
    case classic
    case modern
}

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

    /// Returns the URL for a specific theme CSS file
    public static func cssURL(for theme: Theme) -> URL? {
        Bundle.module.url(forResource: theme.rawValue, withExtension: "css")
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
