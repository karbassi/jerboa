#if DEBUG
import AppKit
import Dispatch
import Foundation

/// On SIGUSR1, dumps the key window's appearance (PNG snapshot of the frame view) and
/// a JSON sidecar with whatever observable state callers have registered via
/// `register(stateDumper:)`. Both files land in `NSTemporaryDirectory()`, or in
/// `JERBOA_SCREENSHOT_DIR` if that env var is set.
///
/// The PNG comes from `NSView.cacheDisplay`, so no Screen Recording permission is
/// needed — but cacheDisplay can't fully capture layer-backed content (SwiftUI Lists in
/// particular). The JSON sidecar fills that gap: callers register a closure returning
/// the state they care about (TOC entries, sync state, displayText prefix, etc.) and
/// the verification path reads the JSON instead of trying to OCR the screenshot.
///
/// Debug-only; never compiled into Release builds.
@MainActor
enum DebugScreenshot {
    typealias StateDumper = @MainActor () -> [String: Any]

    /// Opaque handle returned by `register`; pass it to `unregister` to remove the
    /// dumper (e.g. on `onDisappear`) so closed windows don't leave stale closures.
    struct Registration: Hashable {
        fileprivate let id: UUID
    }

    nonisolated(unsafe) private static var source: DispatchSourceSignal?
    nonisolated(unsafe) private static var stateDumpers: [(id: UUID, dump: StateDumper)] = []

    static func install() {
        guard source == nil else { return }
        signal(SIGUSR1, SIG_IGN)
        let s = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        s.setEventHandler {
            Task { @MainActor in capture() }
        }
        s.resume()
        source = s
    }

    /// Register a closure that returns the state to dump alongside the next snapshot.
    /// Returns a `Registration` token the caller passes to `unregister` on teardown.
    @discardableResult
    static func register(stateDumper: @escaping StateDumper) -> Registration {
        let id = UUID()
        stateDumpers.append((id, stateDumper))
        return Registration(id: id)
    }

    static func unregister(_ registration: Registration) {
        stateDumpers.removeAll { $0.id == registration.id }
    }

    @MainActor
    private static func capture() {
        let dir = ProcessInfo.processInfo.environment["JERBOA_SCREENSHOT_DIR"]
            ?? NSTemporaryDirectory()

        capturePNG(toDir: dir)
        captureState(toDir: dir)
    }

    @MainActor
    private static func capturePNG(toDir dir: String) {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            return
        }
        let frameView = window.contentView?.superview ?? window.contentView
        guard let view = frameView else { return }
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0,
              let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            return
        }
        view.cacheDisplay(in: bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            NSLog("[DebugScreenshot] PNG encoding failed")
            return
        }
        let path = (dir as NSString).appendingPathComponent("jerboa-screenshot.png")
        do {
            try png.write(to: URL(fileURLWithPath: path))
            NSLog("[DebugScreenshot] wrote %d bytes to %@", png.count, path)
        } catch {
            NSLog("[DebugScreenshot] write failed: %@", error.localizedDescription)
        }
    }

    @MainActor
    private static func captureState(toDir dir: String) {
        guard !stateDumpers.isEmpty else { return }
        var windows: [[String: Any]] = []
        for entry in stateDumpers {
            windows.append(entry.dump())
        }
        let payload: [String: Any] = ["windows": windows]
        let path = (dir as NSString).appendingPathComponent("jerboa-state.json")
        do {
            let data = try JSONSerialization.data(
                withJSONObject: payload,
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: URL(fileURLWithPath: path))
            NSLog("[DebugScreenshot] wrote state for %d window(s) to %@", windows.count, path)
        } catch {
            NSLog("[DebugScreenshot] state dump failed: %@", error.localizedDescription)
        }
    }
}
#endif
