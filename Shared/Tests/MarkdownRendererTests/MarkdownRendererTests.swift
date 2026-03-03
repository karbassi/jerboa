import Foundation
import Testing
@testable import MarkdownRenderer

@Suite("MarkdownRenderer")
struct MarkdownRendererTests {
    @Test func viewerHTMLContainsExpectedContent() throws {
        let html = try MarkdownRenderer.viewerHTML()
        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("markdown-it.min.js"))
        #expect(html.contains("markdown-it-github-alerts.min.js"))
        #expect(html.contains("viewer.js"))
    }

    @Test func resourceDirectoryExists() throws {
        let url = MarkdownRenderer.resourceDirectoryURL()
        #expect(url != nil)
    }

    @Test func allResourceFilesExist() throws {
        let resources = ["viewer.html", "base.css", "modern.css",
                         "markdown-it.min.js", "markdown-it-footnote.min.js",
                         "markdown-it-task-lists.min.js",
                         "markdown-it-github-alerts.min.js", "viewer.js"]
        for resource in resources {
            let ext = (resource as NSString).pathExtension
            let name = (resource as NSString).deletingPathExtension
            let url = Bundle.module.url(forResource: name, withExtension: ext)
            #expect(url != nil, "Missing resource: \(resource)")
        }
    }
}
