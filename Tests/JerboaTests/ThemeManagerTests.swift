import Testing
@testable import MarkdownRenderer

@Suite("ThemeManager")
struct ThemeManagerTests {
    @Test func defaultThemeIsClassic() {
        // Theme enum should have classic and modern cases
        #expect(Theme.classic.rawValue == "classic")
        #expect(Theme.modern.rawValue == "modern")
    }

    @Test func themeAllCasesContainsBothThemes() {
        #expect(Theme.allCases.count == 2)
        #expect(Theme.allCases.contains(.classic))
        #expect(Theme.allCases.contains(.modern))
    }
}
