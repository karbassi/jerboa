import AppKit
import Foundation

/// Executes a `LinkAction`. Pairs with `LinkResolver`: the resolver decides what kind of
/// link it is, the dispatcher decides what to do about it.
@MainActor
public protocol LinkActionDispatching {
    func execute(_ action: LinkAction)
}

/// Production dispatcher.
///
/// `openURL` and `openFile` route through `NSWorkspace.shared.open`, which lets Launch
/// Services pick the right app for the URL or non-Markdown file (browser for http(s),
/// Preview for images, etc.).
///
/// `openDocument` explicitly routes back to Jerboa via `NSWorkspace.shared.open(_:
/// withApplicationAt:)` using the running app's bundle URL — otherwise Launch Services
/// would route Markdown links to whatever app the Reader has set as their default `.md`
/// handler. ADR-0001's window-per-Document rule says the linked Document opens in
/// Jerboa, not the system default.
///
/// All calls are injected as closures so tests substitute spies and assert routing
/// without firing real side effects.
@MainActor
public struct SystemLinkActionDispatcher: LinkActionDispatching {
    private let openURL: (URL) -> Void
    private let openDocument: (URL) -> Void

    public init(
        openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) },
        openDocument: @escaping (URL) -> Void = { url in
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: Bundle.main.bundleURL,
                configuration: config
            ) { _, _ in }
        }
    ) {
        self.openURL = openURL
        self.openDocument = openDocument
    }

    public func execute(_ action: LinkAction) {
        switch action {
        case .openURL(let url):      openURL(url)
        case .openDocument(let url): openDocument(url)
        case .openFile(let url):     openURL(url)
        case .none:                  break
        }
    }
}
