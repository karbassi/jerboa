import XCTest

/// Base class for Jerboa UI tests.
///
/// Subclasses pick a launch mode:
///
/// - **Shared app, read-only** — override `class func setUp()` to call
///   `launchSharedApp(fixture:)` once per class. Use this when tests don't mutate
///   on-disk state. The `app` static is reused; per-test `setUp` is empty.
///
/// - **Fresh app per test** — override instance `setUp()` and call `launchApp(fixture:)`
///   on a per-test fixture. Use this when a test mutates the file (reload, watcher) and
///   needs an isolated copy.
@MainActor
class JerboaUITestCase: XCTestCase { // swiftlint:disable:this final_test_case
    static var sharedApp: XCUIApplication?
    var app: XCUIApplication!  // swiftlint:disable:this implicitly_unwrapped_optional

    /// URL of a bundled fixture by filename. Fixtures live in
    /// `Tests/JerboaUITests/Fixtures/` and are referenced via `#filePath` so
    /// they're discoverable in any build configuration.
    static func fixtureURL(_ filename: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(filename)
    }

    /// Launches Jerboa via XCUIApplication (so its windows are introspectable),
    /// passing `fixturePath` as a CLI argument. Waits for the window and the first
    /// TOC entry to appear, which proves the WebView rendered and viewer.js posted
    /// tocData.
    ///
    /// `-ApplePersistenceIgnoreState YES` disables macOS automatic window state
    /// restoration — without this, leftover windows from previous test runs
    /// reopen on launch and pollute `app.windows` queries.
    @discardableResult
    static func launchApp(fixturePath: String) -> XCUIApplication {
        clearSavedState()
        let app = XCUIApplication(bundleIdentifier: "com.karbassi.Jerboa")
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            fixturePath,
        ]
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "App window did not appear")

        // Wait for content to be ready: the toc-sidebar accessibility identifier
        // exists once ContentView renders, and at least one TOC button appears
        // once viewer.js posts tocData.
        let firstHeading = app.outlines.firstMatch.buttons.firstMatch
        _ = firstHeading.waitForExistence(timeout: 10)
        return app
    }

    /// Class-level shared launch. Use in `class func setUp` for read-only tests.
    static func launchSharedApp(fixture filename: String) {
        let url = fixtureURL(filename)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path),
            "Fixture not found at \(url.path)"
        )
        sharedApp = launchApp(fixturePath: url.path)
    }

    static func terminateSharedApp() {
        sharedApp?.terminate()
        sharedApp = nil
    }

    /// macOS persists a per-app window-state plist in
    /// `~/Library/Saved Application State/com.karbassi.Jerboa.savedState`.
    /// On launch, that plist reopens previously-open documents — fine in
    /// production, deadly in tests where every previous run's documents
    /// stack up. Wipe it before each launch.
    private static func clearSavedState() {
        let path = ("~/Library/Saved Application State/com.karbassi.Jerboa.savedState"
            as NSString).expandingTildeInPath
        try? FileManager.default.removeItem(atPath: path)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        if let shared = Self.sharedApp {
            app = shared
        }
    }
}
