import Foundation
import Testing
@testable import Rendering
import MarkdownRenderer

/// Parsing the JS↔Swift bridge messages is pure logic — given a name and a
/// JS-side payload, return a typed event. These tests pin the contract.
@Suite("ScriptMessageParser")
struct ScriptMessageParserTests {

    // MARK: - tocData

    @Test func parsesTOCDataWithValidJSON() {
        let payload = """
        [{"id":"intro","title":"Intro","level":2}]
        """
        let result = ScriptMessageParser.parse(name: "tocData", body: payload)
        #expect(result == .toc([Heading(id: "intro", title: "Intro", level: 2)]))
    }

    @Test func parsesTOCDataWithEmptyArray() {
        let result = ScriptMessageParser.parse(name: "tocData", body: "[]")
        #expect(result == .toc([]))
    }

    @Test func tocDataWithMalformedJSONFallsBackToEmpty() {
        // viewer.js may produce a malformed payload during teardown or under a
        // bug — the bridge shouldn't crash. Empty-list is the safe degenerate.
        let result = ScriptMessageParser.parse(name: "tocData", body: "{not json")
        #expect(result == .toc([]))
    }

    @Test func tocDataWithNonStringBodyFallsBackToEmpty() {
        let result = ScriptMessageParser.parse(name: "tocData", body: 42)
        #expect(result == .toc([]))
    }

    // MARK: - scrollPosition

    @Test func parsesScrollPositionWithHeadingID() {
        #expect(
            ScriptMessageParser.parse(name: "scrollPosition", body: "section-a")
                == .scrollPosition("section-a")
        )
    }

    @Test func emptyStringScrollPositionMeansNoActiveHeading() {
        // viewer.js posts an empty string when no heading is in view (e.g.,
        // scrolled above the first heading). The bridge translates that to nil
        // so SwiftUI's @Published activeHeadingID can clear.
        #expect(
            ScriptMessageParser.parse(name: "scrollPosition", body: "")
                == .scrollPosition(nil)
        )
    }

    @Test func scrollPositionWithNonStringBodyIsNil() {
        // Defensive: the bridge wouldn't post anything but a string, but if
        // something does, treat it as "no active heading" rather than crashing.
        #expect(
            ScriptMessageParser.parse(name: "scrollPosition", body: 0)
                == .scrollPosition(nil)
        )
    }

    // MARK: - openLink

    @Test func parsesOpenLink() {
        #expect(
            ScriptMessageParser.parse(name: "openLink", body: "target.md")
                == .openLink("target.md")
        )
    }

    @Test func openLinkWithNonStringBodyReturnsNil() {
        // No href, no action — caller skips dispatch.
        #expect(ScriptMessageParser.parse(name: "openLink", body: 1) == nil)
    }

    // MARK: - Unknown

    @Test func unknownMessageNameReturnsNil() {
        // Future-proofing: if the bridge ever receives an unregistered name,
        // ignore it rather than crash. Per ADR-0005 the bridge stays narrow,
        // so this should never hit in practice.
        #expect(
            ScriptMessageParser.parse(name: "somethingNew", body: "x") == nil
        )
    }
}
