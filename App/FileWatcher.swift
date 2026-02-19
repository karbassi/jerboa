import Foundation

@MainActor
final class FileWatcher {
    var onChange: (() -> Void)?

    private var fileDescriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private let url: URL

    init(url: URL) {
        self.url = url
        startWatching()
    }

    func stop() {
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }

    private func startWatching() {
        stop()

        let path = url.path(percentEncoded: false)
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = source.data
            if flags.contains(.rename) || flags.contains(.delete) {
                self.startWatching()
            }
            self.onChange?()
        }

        source.setCancelHandler { [fd = fileDescriptor] in
            close(fd)
        }

        source.resume()
        self.source = source
    }
}
