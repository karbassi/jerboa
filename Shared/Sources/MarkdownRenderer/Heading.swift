import Foundation

/// A Markdown heading inside a Document. The marker for a Section.
///
/// Emitted by `viewer.js` over the `tocData` script message so the App can render the
/// table-of-contents sidebar and track the active heading as the Reader scrolls. See
/// CONTEXT.md for the domain definition.
public struct Heading: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let level: Int

    public init(id: String, title: String, level: Int) {
        self.id = id
        self.title = title
        self.level = level
    }
}
