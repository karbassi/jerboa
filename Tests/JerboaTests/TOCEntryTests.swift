import Testing
import Foundation

@Suite("TOCEntry")
struct TOCEntryTests {
    @Test func decodesFromJSON() throws {
        let json = """
        [{"id":"introduction","title":"Introduction","level":2},{"id":"details","title":"Details","level":3}]
        """
        let data = json.data(using: .utf8)!

        struct TOCEntry: Identifiable, Codable, Equatable {
            let id: String
            let title: String
            let level: Int
        }

        let entries = try JSONDecoder().decode([TOCEntry].self, from: data)
        #expect(entries.count == 2)
        #expect(entries[0].id == "introduction")
        #expect(entries[0].title == "Introduction")
        #expect(entries[0].level == 2)
        #expect(entries[1].level == 3)
    }
}
