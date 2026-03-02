import Foundation

enum LinkAction: Equatable {
    case openURL(URL)
    case openDocument(URL)
    case openFile(URL)
    case none
}

enum LinkResolver {
    static func resolve(
        _ href: String,
        relativeTo baseURL: URL?,
        fileExists: (String) -> Bool = FileManager.default.fileExists
    ) -> LinkAction {
        // URL schemes like mailto:, tel:, etc.
        if let url = URL(string: href), let scheme = url.scheme,
           !scheme.isEmpty, scheme != "file" {
            return .openURL(url)
        }

        // File path: strip fragment, resolve against document directory
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
