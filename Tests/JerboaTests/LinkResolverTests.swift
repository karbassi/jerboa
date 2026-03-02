import Testing
import Foundation
@testable import Jerboa

@Suite("LinkResolver")
struct LinkResolverTests {
    let baseURL = URL(fileURLWithPath: "/Users/test/Documents")
    let alwaysExists: (String) -> Bool = { _ in true }
    let neverExists: (String) -> Bool = { _ in false }

    // MARK: - URL scheme links

    @Test func mailtoOpensAsURL() {
        let action = LinkResolver.resolve("mailto:hi@example.com", relativeTo: baseURL)
        #expect(action == .openURL(URL(string: "mailto:hi@example.com")!))
    }

    @Test func telOpensAsURL() {
        let action = LinkResolver.resolve("tel:+1234567890", relativeTo: baseURL)
        #expect(action == .openURL(URL(string: "tel:+1234567890")!))
    }

    @Test func customSchemeOpensAsURL() {
        let action = LinkResolver.resolve("slack://open", relativeTo: baseURL)
        #expect(action == .openURL(URL(string: "slack://open")!))
    }

    // MARK: - HTTP(S) links

    @Test func httpOpensAsURL() {
        let action = LinkResolver.resolve("http://example.com", relativeTo: baseURL)
        #expect(action == .openURL(URL(string: "http://example.com")!))
    }

    @Test func httpsOpensAsURL() {
        let action = LinkResolver.resolve("https://example.com/page", relativeTo: baseURL)
        #expect(action == .openURL(URL(string: "https://example.com/page")!))
    }

    // MARK: - Relative markdown files

    @Test func relativeMarkdownOpensAsDocument() {
        let action = LinkResolver.resolve(
            "./notes.md", relativeTo: baseURL, fileExists: alwaysExists
        )
        let expected = URL(fileURLWithPath: "/Users/test/Documents/notes.md")
        #expect(action == .openDocument(expected))
    }

    @Test func relativeMarkdownExtensionOpensAsDocument() {
        let action = LinkResolver.resolve(
            "readme.markdown", relativeTo: baseURL, fileExists: alwaysExists
        )
        let expected = URL(fileURLWithPath: "/Users/test/Documents/readme.markdown")
        #expect(action == .openDocument(expected))
    }

    // MARK: - Relative non-markdown files

    @Test func relativeTextFileOpensAsFile() {
        let action = LinkResolver.resolve(
            "./data.csv", relativeTo: baseURL, fileExists: alwaysExists
        )
        let expected = URL(fileURLWithPath: "/Users/test/Documents/data.csv")
        #expect(action == .openFile(expected))
    }

    // MARK: - Absolute paths

    @Test func absoluteMarkdownOpensAsDocument() {
        let action = LinkResolver.resolve(
            "/tmp/notes.md", relativeTo: baseURL, fileExists: alwaysExists
        )
        let expected = URL(fileURLWithPath: "/tmp/notes.md")
        #expect(action == .openDocument(expected))
    }

    @Test func absoluteNonMarkdownOpensAsFile() {
        let action = LinkResolver.resolve(
            "/tmp/image.png", relativeTo: baseURL, fileExists: alwaysExists
        )
        let expected = URL(fileURLWithPath: "/tmp/image.png")
        #expect(action == .openFile(expected))
    }

    // MARK: - Fragment stripping

    @Test func fragmentStrippedBeforeResolution() {
        let action = LinkResolver.resolve(
            "./other.md#section", relativeTo: baseURL, fileExists: alwaysExists
        )
        let expected = URL(fileURLWithPath: "/Users/test/Documents/other.md")
        #expect(action == .openDocument(expected))
    }

    @Test func absolutePathWithFragment() {
        let action = LinkResolver.resolve(
            "/tmp/doc.md#heading", relativeTo: baseURL, fileExists: alwaysExists
        )
        let expected = URL(fileURLWithPath: "/tmp/doc.md")
        #expect(action == .openDocument(expected))
    }

    // MARK: - File does not exist

    @Test func nonexistentFileReturnsNone() {
        let action = LinkResolver.resolve(
            "./missing.md", relativeTo: baseURL, fileExists: neverExists
        )
        #expect(action == .none)
    }

    // MARK: - No base URL

    @Test func relativePathWithoutBaseURLReturnsNone() {
        let action = LinkResolver.resolve(
            "./notes.md", relativeTo: nil, fileExists: alwaysExists
        )
        #expect(action == .none)
    }

    @Test func absolutePathWorksWithoutBaseURL() {
        let action = LinkResolver.resolve(
            "/tmp/notes.md", relativeTo: nil, fileExists: alwaysExists
        )
        let expected = URL(fileURLWithPath: "/tmp/notes.md")
        #expect(action == .openDocument(expected))
    }

    // MARK: - Path normalization

    @Test func dotDotPathIsNormalized() {
        let action = LinkResolver.resolve(
            "../sibling/file.md", relativeTo: baseURL, fileExists: alwaysExists
        )
        let expected = URL(fileURLWithPath: "/Users/test/sibling/file.md")
        #expect(action == .openDocument(expected))
    }
}
