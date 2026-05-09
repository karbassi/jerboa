import Foundation
import Testing
@testable import DocumentSync

/// File-watcher tests are end-to-end: each test creates a real temp file, constructs a
/// real watcher, performs a real filesystem operation, and waits for the fsevent + debounce
/// to deliver. They run on the main actor because the watcher's queue is the main queue.
@Suite("FileWatcher")
@MainActor
struct FileWatcherTests {
    /// One-shot recorder that fulfils its continuation on the first event.
    private final class EventRecorder {
        var events: [FileWatcherEvent] = []
        private var continuation: CheckedContinuation<FileWatcherEvent, Never>?

        func record(_ event: FileWatcherEvent) {
            events.append(event)
            if let continuation {
                self.continuation = nil
                continuation.resume(returning: event)
            }
        }

        func waitForOne() async -> FileWatcherEvent {
            await withCheckedContinuation { continuation in
                if let event = events.first {
                    continuation.resume(returning: event)
                } else {
                    self.continuation = continuation
                }
            }
        }
    }

    private func makeTempFile(_ contents: String = "v1") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("filewatchertests-\(UUID().uuidString).md")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Construction

    @Test func initWithExistingFile_succeeds() throws {
        let url = try makeTempFile()
        defer { cleanup(url) }
        #expect(FileWatcher(url: url) != nil)
    }

    @Test func initWithMissingFile_returnsNil() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).md")
        #expect(FileWatcher(url: url) == nil)
    }

    // MARK: - Event delivery

    @Test func writeEmitsChanged() async throws {
        let url = try makeTempFile("v1")
        defer { cleanup(url) }
        let watcher = try #require(FileWatcher(url: url))
        let recorder = EventRecorder()
        watcher.onEvent = { recorder.record($0) }

        try "v2".write(to: url, atomically: false, encoding: .utf8)

        let event = await recorder.waitForOne()
        #expect(event == .changed)
    }

    @Test func deleteEmitsVanished() async throws {
        let url = try makeTempFile("v1")
        let watcher = try #require(FileWatcher(url: url))
        let recorder = EventRecorder()
        watcher.onEvent = { recorder.record($0) }

        try FileManager.default.removeItem(at: url)

        let event = await recorder.waitForOne()
        #expect(event == .vanished)
    }

    @Test func atomicSaveEmitsChanged() async throws {
        // Editors like vim and VSCode write to a temp file and rename it over the
        // original. From the watcher's perspective: .rename event on the watched FD,
        // but the path immediately points to a fresh inode. The watcher should re-arm
        // and emit .changed (not .vanished).
        let url = try makeTempFile("v1")
        defer { cleanup(url) }
        let watcher = try #require(FileWatcher(url: url))
        let recorder = EventRecorder()
        watcher.onEvent = { recorder.record($0) }

        let temp = url.deletingLastPathComponent()
            .appendingPathComponent("filewatchertests-tmp-\(UUID().uuidString).md")
        try "v2".write(to: temp, atomically: false, encoding: .utf8)
        // POSIX rename overwrites the destination atomically — exactly what vim and
        // VSCode do on save. The watched fd's inode is unlinked; the path now points
        // at the new inode.
        let result = rename(temp.path, url.path)
        #expect(result == 0)

        let event = await recorder.waitForOne()
        #expect(event == .changed)
    }

    // MARK: - Debouncing

    @Test func multipleWritesWithinDebounceCoalesce() async throws {
        let url = try makeTempFile("v1")
        defer { cleanup(url) }
        let watcher = try #require(FileWatcher(url: url, debounceInterval: 0.2))
        let recorder = EventRecorder()
        watcher.onEvent = { recorder.record($0) }

        // Write three times within 50ms — well inside the 200ms debounce window.
        try "v2".write(to: url, atomically: false, encoding: .utf8)
        try await Task.sleep(for: .milliseconds(20))
        try "v3".write(to: url, atomically: false, encoding: .utf8)
        try await Task.sleep(for: .milliseconds(20))
        try "v4".write(to: url, atomically: false, encoding: .utf8)

        // Wait long enough for the debounce window to elapse plus delivery.
        try await Task.sleep(for: .milliseconds(400))

        #expect(recorder.events == [.changed])
    }

    // MARK: - Stop

    @Test func stopPreventsFutureEvents() async throws {
        let url = try makeTempFile("v1")
        defer { cleanup(url) }
        let watcher = try #require(FileWatcher(url: url))
        let recorder = EventRecorder()
        watcher.onEvent = { recorder.record($0) }

        watcher.stop()

        try "v2".write(to: url, atomically: false, encoding: .utf8)
        try await Task.sleep(for: .milliseconds(300))

        #expect(recorder.events.isEmpty)
    }
}
