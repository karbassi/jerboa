import SwiftUI

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
    @FocusedValue(\.coordinator) private var coordinator

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
        }
        .defaultSize(width: 900, height: 700)
        .commands {
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
                .keyboardShortcut("+", modifiers: .command)
            }

            CommandGroup(before: .sidebar) {
                Button("Toggle Sidebar") {
                    NSApp.sendAction(
                        #selector(NSSplitViewController.toggleSidebar(_:)),
                        to: nil,
                        from: nil
                    )
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }
        }
    }
}
