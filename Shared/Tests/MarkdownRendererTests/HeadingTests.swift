import Foundation
import Testing
@testable import MarkdownRenderer

@Suite("Heading")
struct HeadingTests {
    @Test func decodesFromTOCDataJSON() throws {
        // The shape viewer.js posts via the tocData script-message handler.
        let json = """
        [
          {"id":"introduction","title":"Introduction","level":2},
          {"id":"details","title":"Details","level":3}
        ]
        """
        let data = Data(json.utf8)

        let entries = try JSONDecoder().decode([Heading].self, from: data)

        #expect(entries.count == 2)
        #expect(entries[0].id == "introduction")
        #expect(entries[0].title == "Introduction")
        #expect(entries[0].level == 2)
        #expect(entries[1].id == "details")
        #expect(entries[1].level == 3)
    }

    @Test func decodesEmptyArray() throws {
        let entries = try JSONDecoder().decode([Heading].self, from: Data("[]".utf8))
        #expect(entries.isEmpty)
    }

    @Test func equatable() {
        let a = Heading(id: "x", title: "X", level: 2)
        let b = Heading(id: "x", title: "X", level: 2)
        let c = Heading(id: "y", title: "X", level: 2)
        #expect(a == b)
        #expect(a != c)
    }
}
