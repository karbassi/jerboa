import Foundation
import MarkdownRenderer

/// A typed event from viewer.js's three named script-message handlers
/// (per ADR-0005).
public enum BridgedScriptMessage: Equatable, Sendable {
    /// `tocData` — the document's heading structure for the sidebar.
    case toc([Heading])
    /// `scrollPosition` — id of the heading currently in view (nil = nothing
    /// past the first heading is in view).
    case scrollPosition(String?)
    /// `openLink` — href of a clicked link, to be resolved through
    /// `LinkResolver` and dispatched.
    case openLink(String)
}

/// Decodes the raw `(name, body)` payloads from `WKScriptMessageHandler`
/// into typed events. Pure: no WebKit, no SwiftUI, no actor isolation.
public enum ScriptMessageParser {
    public static func parse(name: String, body: Any) -> BridgedScriptMessage? {
        switch name {
        case "tocData":
            guard let json = body as? String,
                  let data = json.data(using: .utf8),
                  let entries = try? JSONDecoder().decode([Heading].self, from: data)
            else { return .toc([]) }
            return .toc(entries)
        case "scrollPosition":
            guard let id = body as? String, !id.isEmpty else {
                return .scrollPosition(nil)
            }
            return .scrollPosition(id)
        case "openLink":
            guard let href = body as? String else { return nil }
            return .openLink(href)
        default:
            return nil
        }
    }
}
