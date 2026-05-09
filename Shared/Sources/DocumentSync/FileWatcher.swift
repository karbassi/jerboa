import Foundation

/// What the watcher tells the outside world.
///
/// `changed` fires for `.write` fsevents and for `.rename`/`.delete` events where the
/// path is still readable after the watcher re-arms (the atomic-save case: an editor
/// wrote to a temp file and renamed it over the original, so the path is replaced
/// rather than empty).
///
/// `vanished` fires when the path is gone — true delete or rename-away with no
/// replacement. The watcher then becomes inert; nothing will fire from it again.
public enum FileWatcherEvent: Equatable, Sendable {
    case changed
    case vanished
}

/// Watches a single file path via a `DispatchSourceFileSystemObject` and emits typed
/// events on the main queue. Debounces bursts (e.g. write-write-write within 100 ms)
/// into one delivery.
///
/// Initialiser is failable: if the file doesn't exist (or isn't readable) at construction
/// time, `init?` returns nil. Callers should treat that as the "Missing" state per
/// ADR-0007 — there's no point watching something that isn't there.
@MainActor
public final class FileWatcher {
    public var onEvent: ((FileWatcherEvent) -> Void)?

    private nonisolated(unsafe) var fileDescriptor: Int32 = -1
    private nonisolated(unsafe) var source: DispatchSourceFileSystemObject?
    private nonisolated(unsafe) var debounceWork: DispatchWorkItem?
    private let url: URL
    private let debounceInterval: TimeInterval

    public init?(url: URL, debounceInterval: TimeInterval = 0.1) {
        self.url = url
        self.debounceInterval = debounceInterval
        guard startWatching() else { return nil }
    }

    deinit {
        let source = self.source
        let work = self.debounceWork
        DispatchQueue.main.async {
            work?.cancel()
            source?.cancel()
        }
    }

    public func stop() {
        debounceWork?.cancel()
        debounceWork = nil
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }

    @discardableResult
    private func startWatching() -> Bool {
        stop()

        let path = url.path(percentEncoded: false)
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return false }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = source.data
            if flags.contains(.rename) || flags.contains(.delete) {
                // Re-arm. If the path is still readable (atomic save replaced it),
                // emit .changed; otherwise the file is genuinely gone.
                if self.startWatching() {
                    self.scheduleEvent(.changed)
                } else {
                    self.scheduleEvent(.vanished)
                }
            } else {
                self.scheduleEvent(.changed)
            }
        }

        source.setCancelHandler { [fd = fileDescriptor] in
            close(fd)
        }

        source.resume()
        self.source = source
        return true
    }

    private func scheduleEvent(_ event: FileWatcherEvent) {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onEvent?(event)
        }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
}
