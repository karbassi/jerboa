import Foundation

/// What `LinkResolver` decides should happen when a Markdown link is clicked.
public enum LinkAction: Equatable, Sendable {
    /// A URL that should be handed to the system (browser, Mail, etc.).
    case openURL(URL)
    /// A `.md` / `.markdown` file that should open as a new Document in a new window.
    case openDocument(URL)
    /// A non-Markdown file that should be opened by whatever the system associates with it.
    case openFile(URL)
    /// The link does not point anywhere actionable.
    case none
}
