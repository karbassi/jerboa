import Testing
import JavaScriptCore
@testable import MarkdownRenderer

@Suite("Linkify")
struct LinkifyTests {
    private func createContext() throws -> JSContext {
        let context = JSContext()!

        guard let resourceDir = MarkdownRenderer.resourceDirectoryURL() else {
            throw NSError(domain: "LinkifyTests", code: 1)
        }

        let mdURL = resourceDir.appendingPathComponent("markdown-it.min.js")
        let mdJS = try String(contentsOf: mdURL, encoding: .utf8)
        context.evaluateScript(mdJS)

        // Mirror the viewer.js setup
        context.evaluateScript("""
        var md = markdownit({ html: true, typographer: true, breaks: true, linkify: true });
        md.linkify.set({ fuzzyLink: false, fuzzyEmail: false, fuzzyIP: false });
        """)

        return context
    }

    private func render(_ context: JSContext, markdown: String) -> String {
        context.evaluateScript("md.render(\(jsStringLiteral(markdown)));")?.toString() ?? ""
    }

    private func jsStringLiteral(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "'\(escaped)'"
    }

    @Test func filenameMdNotLinked() throws {
        let ctx = try createContext()
        let html = render(ctx, markdown: "Read the README.md.")
        #expect(!html.contains("<a "))
    }

    @Test func filenameIoNotLinked() throws {
        let ctx = try createContext()
        let html = render(ctx, markdown: "See notes.io for details.")
        #expect(!html.contains("<a "))
    }

    @Test func filenameAppNotLinked() throws {
        let ctx = try createContext()
        let html = render(ctx, markdown: "Open config.app now.")
        #expect(!html.contains("<a "))
    }

    @Test func explicitHttpsIsLinked() throws {
        let ctx = try createContext()
        let html = render(ctx, markdown: "Visit https://example.com today.")
        #expect(html.contains("<a "))
        #expect(html.contains("https://example.com"))
    }

    @Test func explicitHttpIsLinked() throws {
        let ctx = try createContext()
        let html = render(ctx, markdown: "Visit http://example.com today.")
        #expect(html.contains("<a "))
        #expect(html.contains("http://example.com"))
    }

    @Test func markdownLinkStillWorks() throws {
        let ctx = try createContext()
        let html = render(ctx, markdown: "Click [here](https://example.com).")
        #expect(html.contains("<a "))
        #expect(html.contains("https://example.com"))
    }

    @Test func bareEmailNotLinked() throws {
        let ctx = try createContext()
        let html = render(ctx, markdown: "Email user@example.com for help.")
        #expect(!html.contains("<a "))
    }
}
