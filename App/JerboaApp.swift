import SwiftUI

private let bundleID = "com.karbassi.Jerboa"

final class AppDelegate: NSObject, NSApplicationDelegate {
    override init() {
        let args = Array(CommandLine.arguments.dropFirst())

        if args.contains("--help") || args.contains("-h") {
            print("""
            Usage: jerboa [file ...]

            Open markdown files in Jerboa.

              jerboa file.md            Open a file
              jerboa file1.md file2.md  Open multiple files
              jerboa                    Launch Jerboa
              jerboa --help             Show this help
            """)
            exit(0)
        }

        // If another instance is already running, delegate to it and exit
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }

        if !others.isEmpty {
            let fileArgs = args.filter { !$0.hasPrefix("-") }
            if fileArgs.isEmpty {
                others.first?.activate()
            } else {
                let cwd = FileManager.default.currentDirectoryPath
                for arg in fileArgs {
                    let path = arg.hasPrefix("/") ? arg : cwd + "/" + arg
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    process.arguments = ["-b", bundleID, path]
                    try? process.run()
                    process.waitUntilExit()
                }
            }
            exit(0)
        }

        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Open files passed as CLI arguments on fresh launch
        let cwd = FileManager.default.currentDirectoryPath
        for arg in CommandLine.arguments.dropFirst() where !arg.hasPrefix("-") {
            let path = arg.hasPrefix("/") ? arg : cwd + "/" + arg
            let fileURL = URL(fileURLWithPath: path)
            NSDocumentController.shared.openDocument(
                withContentsOf: fileURL, display: true) { _, _, _ in }
        }

        // Handle jerboa:// URL scheme
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURL(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleURL(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString),
              url.scheme == "jerboa", url.host == "open",
              let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                  .queryItems?.first(where: { $0.name == "path" })?.value
        else { return }
        let fileURL = URL(fileURLWithPath: path)
        NSDocumentController.shared.openDocument(
            withContentsOf: fileURL, display: true) { _, _, _ in }
    }
}

struct CoordinatorKey: FocusedValueKey {
    typealias Value = WebViewCoordinator
}

extension FocusedValues {
    var coordinator: WebViewCoordinator? {
        get { self[CoordinatorKey.self] }
        set { self[CoordinatorKey.self] = newValue }
    }
}

@main
struct JerboaApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @FocusedValue(\.coordinator) private var coordinator

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
        }
        .defaultSize(width: 900, height: 700)
        .commands {
            CommandGroup(replacing: .saveItem) {}
            CommandGroup(replacing: .pasteboard) {}
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(after: .toolbar) {
                Button("Reset Font Size") {
                    coordinator?.resetFontSize()
                }
                .keyboardShortcut("0", modifiers: .command)

                Button("Decrease Font Size") {
                    coordinator?.decreaseFontSize()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Increase Font Size") {
                    coordinator?.increaseFontSize()
                }
                .keyboardShortcut("=", modifiers: .command)
            }
        }
    }
}
