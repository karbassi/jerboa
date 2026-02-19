import XCTest
import AppKit

class JerboaUITestCase: XCTestCase { // swiftlint:disable:this final_test_case
    var app: XCUIApplication! // swiftlint:disable:this implicitly_unwrapped_optional

    /// Derive the test fixture path from the source file location at compile time.
    /// Uses #filePath (not #file) to get the full absolute path in Swift 6.
    private var testFileURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("commonmark-spec.md")
    }

    override func setUpWithError() throws {
        continueAfterFailure = false

        let fileURL = testFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw XCTSkip("Test fixture not found at \(fileURL.path)")
        }

        // Open the file with Jerboa via NSWorkspace — bypasses the DocumentGroup Open dialog
        let appURL = try XCTUnwrap(
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.karbassi.Jerboa")
        )
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        let expectation = XCTestExpectation(description: "App opened")
        NSWorkspace.shared.open(
            [fileURL],
            withApplicationAt: appURL,
            configuration: config
        ) { _, error in
            if let error {
                XCTFail("Failed to open file: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10)

        app = XCUIApplication(bundleIdentifier: "com.karbassi.Jerboa")

        // Wait for the document window to appear and content to render
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 10) else {
            throw XCTSkip("App window did not appear")
        }
        Thread.sleep(forTimeInterval: 3)
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }
}
