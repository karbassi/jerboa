import JerboaCLI
import SwiftUI

private let bundleID = "com.karbassi.Jerboa"

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    override init() {
        let args = Array(CommandLine.arguments.dropFirst())
        let cwd = FileManager.default.currentDirectoryPath
        let action = JerboaCLI.parse(arguments: args, cwd: cwd)

        switch action {
        case .showHelp:
            print(JerboaCLI.helpText)
            exit(0)

        case .openFiles(let paths):
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            if !others.isEmpty {
                for path in paths {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    process.arguments = ["-b", bundleID, path]
                    try? process.run()
                    process.waitUntilExit()
                }
                exit(0)
            }

        case .launch:
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            if let other = others.first {
                other.activate()
                exit(0)
            }
        }

        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        DebugScreenshot.install()
        #endif

        // Open files passed as CLI arguments on fresh launch
        let cwd = FileManager.default.currentDirectoryPath
        let action = JerboaCLI.parse(
            arguments: Array(CommandLine.arguments.dropFirst()),
            cwd: cwd
        )
        if case .openFiles(let paths) = action {
            for path in paths {
                NSDocumentController.shared.openDocument(
                    withContentsOf: URL(fileURLWithPath: path),
                    display: true
                ) { _, _, _ in }
            }
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

    // MARK: - Menu cleanup

    func setupMenuDelegates() {
        guard let mainMenu = NSApp.mainMenu else { return }
        for item in mainMenu.items {
            switch item.title {
            case "Theme", "Help":
                item.isHidden = true
            case "File":
                item.submenu?.delegate = self
                if let submenu = item.submenu {
                    cleanUpFileMenu(submenu)
                    cleanUpSeparators(submenu)
                }
            case "Edit":
                item.submenu?.delegate = self
                if let submenu = item.submenu {
                    cleanUpEditMenu(submenu)
                    cleanUpSeparators(submenu)
                }
            default:
                break
            }
        }
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        switch menu.title {
        case "File":
            cleanUpFileMenu(menu)
        case "Edit":
            cleanUpEditMenu(menu)
        default:
            break
        }
        cleanUpSeparators(menu)
    }

    private func cleanUpFileMenu(_ menu: NSMenu) {
        let hideActions: Set<String> = [
            "newDocument:",
            "saveDocument:", "saveDocumentAs:",
            "duplicateDocument:", "renameDocument:", "moveDocument:",
            "browseDocumentVersions:",
        ]
        let hideByTitle: Set<String> = ["Share", "Revert To"]
        for item in menu.items {
            if item.isSeparatorItem { continue }
            if let action = item.action, hideActions.contains(NSStringFromSelector(action)) {
                item.isHidden = true
            } else if hideByTitle.contains(item.title) {
                item.isHidden = true
            }
        }
    }

    private func cleanUpEditMenu(_ menu: NSMenu) {
        let keepActions: Set<String> = [
            "copy:", "selectAll:",
            "startDictation:", "orderFrontCharacterPalette:",
        ]
        for item in menu.items {
            if item.isSeparatorItem { continue }
            if let action = item.action, keepActions.contains(NSStringFromSelector(action)) {
                continue
            }
            item.isHidden = true
        }
    }

    private func cleanUpSeparators(_ menu: NSMenu) {
        var lastVisibleWasSeparator = true
        for item in menu.items {
            if item.isHidden { continue }
            if item.isSeparatorItem {
                if lastVisibleWasSeparator {
                    item.isHidden = true
                }
                lastVisibleWasSeparator = true
            } else {
                lastVisibleWasSeparator = false
            }
        }
        if let last = menu.items.last(where: { !$0.isHidden }), last.isSeparatorItem {
            last.isHidden = true
        }
    }
}

struct CoordinatorKey: FocusedValueKey {
    typealias Value = WebViewCoordinator
}

struct ReloadActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var coordinator: WebViewCoordinator? {
        get { self[CoordinatorKey.self] }
        set { self[CoordinatorKey.self] = newValue }
    }

    var reloadAction: (() -> Void)? {
        get { self[ReloadActionKey.self] }
        set { self[ReloadActionKey.self] = newValue }
    }
}

@main
struct JerboaApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @FocusedValue(\.coordinator) private var coordinator
    @FocusedValue(\.reloadAction) private var reloadAction

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.appDelegate.setupMenuDelegates()
                    }
                }
        }
        .defaultSize(width: 900, height: 700)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Jerboa") {
                    let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
                        ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
                        ?? "unknown"
                    let sha = Bundle.main.object(forInfoDictionaryKey: "GitCommitSHA") as? String ?? "unknown"
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationVersion: "\(version) (\(sha))",
                    ])
                }
            }
            CommandGroup(after: .newItem) {
                Button("Reload") {
                    reloadAction?()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(reloadAction == nil)
            }
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
