import Testing
@testable import MarkdownRenderer

@Suite("MarkdownRenderer")
struct MarkdownRendererBasicTests {
    @Test func viewerHTMLURLExists() {
        #expect(MarkdownRenderer.viewerHTMLURL() != nil)
    }

    @Test func resourceDirectoryExists() {
        #expect(MarkdownRenderer.resourceDirectoryURL() != nil)
    }
}
