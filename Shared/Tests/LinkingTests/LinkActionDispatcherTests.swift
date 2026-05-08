import Foundation
import Testing
@testable import Linking

@Suite("SystemLinkActionDispatcher routing")
@MainActor
struct LinkActionDispatcherTests {
    /// Recording dispatcher used in every test. Both spies start nil; after `execute` runs,
    /// at most one of them should be set to the URL the action carried.
    private final class Spy {
        var openedURL: URL?
        var openedDocument: URL?
    }

    private func makeDispatcher(spy: Spy) -> SystemLinkActionDispatcher {
        SystemLinkActionDispatcher(
            openURL: { spy.openedURL = $0 },
            openDocument: { spy.openedDocument = $0 }
        )
    }

    @Test func openURL_routesToOpenURLClosure() {
        let spy = Spy()
        let url = URL(string: "https://example.com")!
        makeDispatcher(spy: spy).execute(.openURL(url))
        #expect(spy.openedURL == url)
        #expect(spy.openedDocument == nil)
    }

    @Test func openDocument_routesToOpenDocumentClosure() {
        let spy = Spy()
        let url = URL(fileURLWithPath: "/tmp/notes.md")
        makeDispatcher(spy: spy).execute(.openDocument(url))
        #expect(spy.openedDocument == url)
        #expect(spy.openedURL == nil)
    }

    @Test func openFile_routesToOpenURLClosure() {
        // Non-Markdown files go through the URL/system-open path, not the document
        // controller — they land in whatever app the OS associates with the type.
        let spy = Spy()
        let url = URL(fileURLWithPath: "/tmp/diagram.png")
        makeDispatcher(spy: spy).execute(.openFile(url))
        #expect(spy.openedURL == url)
        #expect(spy.openedDocument == nil)
    }

    @Test func none_doesNothing() {
        let spy = Spy()
        makeDispatcher(spy: spy).execute(.none)
        #expect(spy.openedURL == nil)
        #expect(spy.openedDocument == nil)
    }
}
