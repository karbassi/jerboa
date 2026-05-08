import Foundation
import Testing
@testable import Rendering

@Suite("RenderingOrchestrator")
@MainActor
struct RenderingOrchestratorTests {
    /// Spy that records every JS expression `evaluate` would have run.
    private final class JSSpy {
        var calls: [String] = []
    }

    private func makeOrchestrator(spy: JSSpy) -> RenderingOrchestrator {
        RenderingOrchestrator(evaluate: { spy.calls.append($0) })
    }

    @Test func render_beforePageLoaded_doesNotFireJS() {
        let spy = JSSpy()
        let orchestrator = makeOrchestrator(spy: spy)

        orchestrator.render("# Hello")

        #expect(spy.calls.isEmpty)
    }

    @Test func render_afterPageLoaded_firesJS() {
        let spy = JSSpy()
        let orchestrator = makeOrchestrator(spy: spy)

        orchestrator.notePageLoaded()
        orchestrator.render("# Hello")

        #expect(spy.calls.count == 1)
        #expect(spy.calls.first?.contains("# Hello") == true)
        #expect(spy.calls.first?.starts(with: "window.renderMarkdown(`") == true)
    }

    @Test func notePageLoaded_flushesPendingRender() {
        // Document arrived before the page was ready — when the page becomes ready, the
        // queued text should fire automatically.
        let spy = JSSpy()
        let orchestrator = makeOrchestrator(spy: spy)

        orchestrator.render("# Hello")
        #expect(spy.calls.isEmpty)

        orchestrator.notePageLoaded()

        #expect(spy.calls.count == 1)
        #expect(spy.calls.first?.contains("# Hello") == true)
    }

    @Test func render_sameTextTwice_firesOnce() {
        let spy = JSSpy()
        let orchestrator = makeOrchestrator(spy: spy)
        orchestrator.notePageLoaded()

        orchestrator.render("# Hello")
        orchestrator.render("# Hello")

        #expect(spy.calls.count == 1)
    }

    @Test func render_differentTextTwice_firesTwice() {
        let spy = JSSpy()
        let orchestrator = makeOrchestrator(spy: spy)
        orchestrator.notePageLoaded()

        orchestrator.render("# Hello")
        orchestrator.render("# World")

        #expect(spy.calls.count == 2)
    }

    @Test func notePageTerminated_thenLoaded_refiresLastRender() {
        // The WebContent process can die (ADR-0003 recovery path). When the new page
        // finishes loading, the most recent Document text must be re-rendered into it
        // — otherwise the window goes blank.
        let spy = JSSpy()
        let orchestrator = makeOrchestrator(spy: spy)
        orchestrator.notePageLoaded()
        orchestrator.render("# Hello")
        #expect(spy.calls.count == 1)

        orchestrator.notePageTerminated()
        // While the page is dead, render shouldn't fire JS to a dead WebView.
        orchestrator.render("# After Crash")
        #expect(spy.calls.count == 1)

        orchestrator.notePageLoaded()
        #expect(spy.calls.count == 2)
        #expect(spy.calls.last?.contains("# After Crash") == true)
    }

    @Test func render_escapesBackticks() {
        // The escape function lives in MarkdownRenderer; this is a sanity check that the
        // orchestrator pipes content through it before dropping it into the JS template.
        let spy = JSSpy()
        let orchestrator = makeOrchestrator(spy: spy)
        orchestrator.notePageLoaded()

        orchestrator.render("here is a `code` span")

        #expect(spy.calls.count == 1)
        // Escaped backticks inside template literals must be \` so they don't terminate
        // the literal early.
        #expect(spy.calls.first?.contains("\\`code\\`") == true)
    }
}
