import Foundation
import Testing
@testable import MarkdownRenderer

@Suite("MarkdownRenderer")
struct MarkdownRendererTests {
    @Test func viewerHTMLContainsExpectedContent() throws {
        let html = try MarkdownRenderer.viewerHTML()
        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("markdown-it.min.js"))
        #expect(html.contains("viewer.js"))
    }

    @Test func resourceDirectoryExists() throws {
        let url = MarkdownRenderer.resourceDirectoryURL()
        #expect(url != nil)
    }

    @Test func allResourceFilesExist() throws {
        let resources = ["viewer.html", "base.css", "classic.css", "modern.css",
                         "markdown-it.min.js", "markdown-it-footnote.min.js",
                         "js-yaml.min.js", "viewer.js"]
        for resource in resources {
            let ext = (resource as NSString).pathExtension
            let name = (resource as NSString).deletingPathExtension
            let url = Bundle.module.url(forResource: name, withExtension: ext)
            #expect(url != nil, "Missing resource: \(resource)")
        }
    }

    @Test func themeCSSFilesExist() throws {
        for theme in Theme.allCases {
            let url = MarkdownRenderer.cssURL(for: theme)
            #expect(url != nil, "Missing CSS for theme: \(theme.rawValue)")
        }
    }
}
