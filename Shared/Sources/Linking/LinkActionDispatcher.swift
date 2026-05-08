import AppKit
import Foundation

/// Executes a `LinkAction`. Pairs with `LinkResolver`: the resolver decides what kind of
/// link it is, the dispatcher decides what to do about it.
@MainActor
public protocol LinkActionDispatching {
    func execute(_ action: LinkAction)
}

/// Production dispatcher: opens Documents through `NSDocumentController`, opens
/// non-Markdown files and remote URLs through `NSWorkspace`. The two system calls are
/// injected as closures so tests can substitute spies and assert routing without firing
/// real side effects.
@MainActor
public struct SystemLinkActionDispatcher: LinkActionDispatching {
    private let openURL: (URL) -> Void
    private let openDocument: (URL) -> Void

    public init(
        openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) },
        openDocument: @escaping (URL) -> Void = { url in
            NSDocumentController.shared.openDocument(
                withContentsOf: url, display: true
            ) { _, _, _ in }
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
