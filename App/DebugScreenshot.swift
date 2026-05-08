#if DEBUG
import AppKit
import Dispatch
import Foundation

/// Listens for SIGUSR1 and writes a snapshot of the key window (including
/// titlebar/toolbar) to `/tmp/jerboa-screenshot.png`, or to the path in
/// `JERBOA_SCREENSHOT_PATH` if that environment variable is set.
///
/// Uses `NSView.cacheDisplay` against the window's frame view, so it works
/// without Screen Recording permission — the app draws its own views into a
/// bitmap. Debug-only; never compiled into Release builds.
@MainActor
enum DebugScreenshot {
    nonisolated(unsafe) private static var source: DispatchSourceSignal?

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

    @MainActor
    private static func capture() {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            return
        }
        // The frame view (NSThemeFrame) contains the contentView plus the
        // titlebar/toolbar/traffic-light area. cacheDisplay against it gives
        // us the whole window without Screen Recording permission.
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
        // Sandboxed apps cannot write to /tmp; use the app's tmp container directory.
        let dir = ProcessInfo.processInfo.environment["JERBOA_SCREENSHOT_DIR"]
            ?? NSTemporaryDirectory()
        let path = (dir as NSString).appendingPathComponent("jerboa-screenshot.png")
        do {
            try png.write(to: URL(fileURLWithPath: path))
            NSLog("[DebugScreenshot] wrote %d bytes to %@", png.count, path)
        } catch {
            NSLog("[DebugScreenshot] write failed: %@", error.localizedDescription)
        }
    }
}
#endif
