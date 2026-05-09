import XCTest

/// Read-only UI tests against a representative Markdown fixture.
///
/// Fixture: `mxstbr/markdown-test-file` (single file derived from John Gruber's
/// Markdown reference, exercising most syntax). Small enough to render fast,
/// broad enough to catch syntax-coverage regressions. One launch shared across
/// the suite; no test mutates state.
final class JerboaReadOnlyUITests: JerboaUITestCase {
    override class func setUp() {
        super.setUp()
        launchSharedApp(fixture: "markdown-test-file.md")
    }

    override class func tearDown() {
        terminateSharedApp()
        super.tearDown()
    }

    /// End-to-end render proof: window appears with the right title; the SwiftUI
    /// sidebar binds to the headings emitted by viewer.js over the tocData
    /// script message; specific accessibility identifiers (set in TOCSidebarView)
    /// match the slugs viewer.js generates.
    func testDocumentRendersWithPopulatedSidebar() {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(
            window.title.contains("markdown-test-file"),
            "Window title should contain the fixture filename, got: \(window.title)"
        )

        let sidebar = app.outlines.firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))

        // Lower-bound assertion — the upstream fixture may evolve over time.
        XCTAssertGreaterThan(
            sidebar.buttons.count, 10,
            "TOC should populate from a representative Markdown document"
        )

        // Specific entries with stable slugs — proves TOCSidebarView's
        // accessibility identifiers match viewer.js's slug generation.
        XCTAssertTrue(sidebar.buttons["toc-overview"].exists)
        XCTAssertTrue(sidebar.buttons["toc-block-elements"].exists)
    }
}

/// Tests that mutate state (reload from disk) launch a fresh app per test.
final class JerboaStateMutatingUITests: JerboaUITestCase {
    private var workdir: URL!  // swiftlint:disable:this implicitly_unwrapped_optional

    override func setUpWithError() throws {
        try super.setUpWithError()
        workdir = FileManager.default.temporaryDirectory
            .appendingPathComponent("jerboa-uitests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workdir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
        if let workdir { try? FileManager.default.removeItem(at: workdir) }
        try super.tearDownWithError()
    }

    /// Clicking a Markdown link to a sibling `.md` opens it in a new Jerboa
    /// window per ADR-0001's window-per-Document rule. Exercises the full chain:
    /// WebView click → openLink message → LinkResolver →
    /// SystemLinkActionDispatcher → NSWorkspace open with bundle URL →
    /// second window in the same process.
    func testCrossDocumentLinkOpensSecondWindow() throws {
        let hub = workdir.appendingPathComponent("hub.md")
        let target = workdir.appendingPathComponent("target.md")
        try "# Hub\n\n[Open Target](target.md)\n".write(to: hub, atomically: true, encoding: .utf8)
        try "# Target Document\n\nReached.\n".write(to: target, atomically: true, encoding: .utf8)

        app = Self.launchApp(fixturePath: hub.path)
        let initialWindowCount = app.windows.count

        // The link in hub.md is rendered as <a href="target.md">Open Target</a>.
        // WKWebView surfaces it as an XCUI link by accessibility.
        let link = app.windows.firstMatch.links["Open Target"]
        XCTAssertTrue(link.waitForExistence(timeout: 5), "Markdown link should be accessible")
        link.click()

        // Wait for window count to increase. Robust to whatever window names
        // macOS or state restoration assigns.
        let predicate = NSPredicate(format: "count > %d", initialWindowCount)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.windows)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: 10),
            .completed,
            "Clicking a Markdown link should open a new window (started with \(initialWindowCount), now \(app.windows.count))"
        )
    }

    /// File → Reload (⌘R) is always available and re-reads the file from disk.
    /// Covers the menu wiring, the FocusedValue plumbing in JerboaApp, the
    /// reloadFromDisk path through DocumentSyncStateMachine, and the rendering
    /// orchestrator picking up the new content.
    func testForceReloadViaMenuShortcut() throws {
        let fixture = workdir.appendingPathComponent("doc.md")
        try "# Original\n".write(to: fixture, atomically: true, encoding: .utf8)
        app = Self.launchApp(fixturePath: fixture.path)

        XCTAssertTrue(
            app.outlines.firstMatch.buttons["toc-original"].waitForExistence(timeout: 5),
            "Initial heading should appear in TOC"
        )

        // Mutate the file and force-reload via ⌘R.
        try "# Forced\n".write(to: fixture, atomically: true, encoding: .utf8)
        app.typeKey("r", modifierFlags: .command)

        XCTAssertTrue(
            app.outlines.firstMatch.buttons["toc-forced"].waitForExistence(timeout: 5),
            "⌘R should pick up the new content"
        )
    }
}

// MARK: - Coverage notes for behaviours not exercised at the XCUITest level
//
// The following behaviours have been deliberately left to lower-level tests
// rather than XCUITest, because they're either unreliable to assert via
// XCUIElement (platform quirks) or already exhaustively covered:
//
// - TOC click → active heading marker. Covered by:
//   - DocumentSyncStateMachine unit tests (state transitions)
//   - viewer.js vitest tests (scrollPosition message round-trip)
//   - SwiftUI Button → accessibilityValue binding is a one-liner with no
//     conditional logic — testing it via XCUITest's `value` property is
//     unreliable on macOS (accessibilityValue doesn't always surface as
//     XCUIElement.value for Buttons inside a List).
//
// - Cross-Document link click opens new window. Covered by:
//   - LinkResolverTests (href → LinkAction)
//   - LinkActionDispatcherTests (LinkAction → openURL/openDocument closures)
//   - Manually verified during #23 work that NSWorkspace.OpenConfiguration
//     with Bundle.main.bundleURL routes back to Jerboa specifically.
//
// - Pending Reload button appears on external change. Covered by:
//   - FileWatcherTests (write → .changed; rename/delete + reopen-fail → .vanished)
//   - DocumentSyncStateMachineTests (every transition in ADR-0007's table)
//   - SwiftUI's @Published binding to .pendingReload is a one-liner.
