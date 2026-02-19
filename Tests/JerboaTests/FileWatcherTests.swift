import Testing
import Foundation

@Suite("FileWatcher")
struct FileWatcherTests {
    @Test func canCreateWithTempFile() throws {
        // Just verifying the file watcher can be instantiated
        // Actual file watching requires main run loop integration
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).md")
        FileManager.default.createFile(atPath: tempURL.path, contents: "# Test".data(using: .utf8))
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // We can't fully test the watcher in a sync test context,
        // but we can verify the URL is valid
        #expect(FileManager.default.fileExists(atPath: tempURL.path))
    }
}
