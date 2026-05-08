import Foundation

/// Decides what kind of action a Markdown link's `href` represents. Pure: takes the href,
/// the Document's containing directory (so relative paths resolve correctly), and a
/// `fileExists` checker (injectable for tests). Returns a `LinkAction`; the act of acting
/// on it is `LinkActionDispatching`'s job.
public enum LinkResolver {
    public static func resolve(
        _ href: String,
        relativeTo baseURL: URL?,
        fileExists: (String) -> Bool = FileManager.default.fileExists
    ) -> LinkAction {
        // URL schemes like mailto:, tel:, etc. — anything with a scheme that isn't "file"
        // is handed off as a URL.
        if let url = URL(string: href), let scheme = url.scheme,
           !scheme.isEmpty, scheme != "file" {
            return .openURL(url)
        }

        // File path: strip fragment, resolve against the Document's directory.
        let withoutFragment = href.components(separatedBy: "#").first ?? href
        let path: String
        if withoutFragment.starts(with: "/") {
            path = withoutFragment
        } else if let baseURL {
            path = baseURL.appendingPathComponent(withoutFragment).path
        } else {
            return .none
        }

        let fileURL = URL(fileURLWithPath: path).standardized

        guard fileExists(fileURL.path) else { return .none }

        let ext = fileURL.pathExtension.lowercased()
        if ext == "md" || ext == "markdown" {
            return .openDocument(fileURL)
        } else {
            return .openFile(fileURL)
        }
    }
}
