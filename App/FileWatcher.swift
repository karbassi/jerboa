import Foundation

enum FileWatcherEvent {
    case changed   // file at the watched path was modified or atomically replaced
    case vanished  // file at the watched path is gone (deleted or renamed away with no replacement)
}

@MainActor
final class FileWatcher {
    var onEvent: ((FileWatcherEvent) -> Void)?

    private nonisolated(unsafe) var fileDescriptor: Int32 = -1
    private nonisolated(unsafe) var source: DispatchSourceFileSystemObject?
    private nonisolated(unsafe) var debounceWork: DispatchWorkItem?
    private let url: URL
    private let debounceInterval: TimeInterval = 0.1

    init?(url: URL) {
        self.url = url
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

    func stop() {
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
