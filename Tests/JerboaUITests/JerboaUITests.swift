import XCTest

final class JerboaUITests: JerboaUITestCase {

    // MARK: - Window & Layout

    func testWindowExists() {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        takeScreenshot(named: "window-exists")
    }

    func testWindowTitle() {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let title = window.title
        XCTAssertTrue(
            title.contains("commonmark-spec"),
            "Window title should contain filename, got: \(title)"
        )
    }

    // MARK: - TOC Sidebar

    func testTOCSidebarShowsEntries() {
        let sidebar = app.outlines.firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10))
        let count = sidebar.buttons.count
        XCTAssertGreaterThan(count, 0, "TOC sidebar should have heading entries")
        takeScreenshot(named: "toc-sidebar-populated")
    }

    func testTOCSidebarHasMultipleEntries() {
        let sidebar = app.outlines.firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10))
        let count = sidebar.buttons.count
        // commonmark-spec.md has many headings
        XCTAssertGreaterThan(count, 5, "TOC should have many entries for commonmark spec, got: \(count)")
    }

    func testTOCClickChangesActiveHeading() {
        let sidebar = app.outlines.firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10))

        let buttons = sidebar.buttons
        guard buttons.count > 1 else {
            XCTFail("Need at least 2 TOC entries to test navigation")
            return
        }

        let lastButton = buttons.element(boundBy: buttons.count - 1)
        lastButton.click()

        Thread.sleep(forTimeInterval: 2)

        XCTAssertEqual(
            lastButton.value as? String, "active",
            "Clicked TOC entry should become active"
        )
        takeScreenshot(named: "toc-click-last-heading")
    }

    func testTOCClickFirstHeading() {
        let sidebar = app.outlines.firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10))

        let buttons = sidebar.buttons
        guard buttons.count > 0 else {
            XCTFail("Need at least 1 TOC entry")
            return
        }

        let firstButton = buttons.element(boundBy: 0)
        firstButton.click()

        Thread.sleep(forTimeInterval: 2)

        XCTAssertEqual(
            firstButton.value as? String, "active",
            "First TOC entry should be active after clicking it"
        )
    }

    // MARK: - Scroll Persistence

    func testScrollDoesNotSnapBack() {
        let sidebar = app.outlines.firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10))

        let buttons = sidebar.buttons
        guard buttons.count > 1 else {
            XCTFail("Need at least 2 TOC entries to test scroll persistence")
            return
        }

        let firstButton = buttons.element(boundBy: 0)
        let lastButton = buttons.element(boundBy: buttons.count - 1)

        lastButton.click()
        Thread.sleep(forTimeInterval: 2)

        XCTAssertEqual(lastButton.value as? String, "active",
                       "Last heading should be active after clicking it")

        takeScreenshot(named: "scroll-at-bottom")

        // Wait 2 more seconds -- the old bug would snap scroll back to top here
        Thread.sleep(forTimeInterval: 2)

        XCTAssertEqual(lastButton.value as? String, "active",
                       "Scroll should NOT snap back -- last heading should still be active")
        XCTAssertNotEqual(firstButton.value as? String, "active",
                          "First heading should NOT become active -- scroll snapped back")

        takeScreenshot(named: "scroll-still-at-bottom")
    }

    func testScrollToMiddleThenNeighbor() {
        let sidebar = app.outlines.firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10))

        let buttons = sidebar.buttons
        guard buttons.count > 3 else {
            XCTFail("Need at least 4 TOC entries")
            return
        }

        let midIndex = buttons.count / 2
        let midButton = buttons.element(boundBy: midIndex)
        midButton.click()
        Thread.sleep(forTimeInterval: 2)

        XCTAssertEqual(midButton.value as? String, "active",
                       "Middle heading should be active")

        // Click a nearby heading (one before mid) to verify navigation works both directions
        let prevButton = buttons.element(boundBy: midIndex - 1)
        prevButton.click()
        Thread.sleep(forTimeInterval: 2)

        XCTAssertEqual(prevButton.value as? String, "active",
                       "Previous heading should be active after clicking it")
        XCTAssertEqual(midButton.value as? String, "inactive",
                       "Middle heading should no longer be active")
    }

    // MARK: - Theme Menu

    func testThemeMenuExists() {
        let menuBar = app.menuBars.firstMatch
        let viewMenu = menuBar.menuBarItems["View"]
        XCTAssertTrue(viewMenu.exists, "View menu should exist in menu bar")

        viewMenu.click()
        XCTAssertTrue(app.menuItems["Classic"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.menuItems["Modern"].exists)
        app.typeKey(.escape, modifierFlags: [])
    }

    func testThemeSwitchToModern() {
        let menuBar = app.menuBars.firstMatch
        let viewMenu = menuBar.menuBarItems["View"]

        viewMenu.click()
        app.menuItems["Modern"].click()
        Thread.sleep(forTimeInterval: 1)

        takeScreenshot(named: "theme-modern")

        // Switch back to Classic
        viewMenu.click()
        app.menuItems["Classic"].click()
        Thread.sleep(forTimeInterval: 1)

        takeScreenshot(named: "theme-classic")
    }

    func testThemeKeyboardShortcuts() {
        // Cmd+Shift+2 for Modern
        app.typeKey("2", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1)
        takeScreenshot(named: "theme-modern-shortcut")

        // Cmd+Shift+1 for Classic
        app.typeKey("1", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1)
        takeScreenshot(named: "theme-classic-shortcut")
    }

    // MARK: - Helpers

    private func takeScreenshot(named name: String) {
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
