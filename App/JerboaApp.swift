import SwiftUI
import MarkdownRenderer

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
    @State private var themeManager = ThemeManager()
    @FocusedValue(\.coordinator) private var coordinator

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
                .environment(themeManager)
        }
        .defaultSize(width: 900, height: 700)
        .commands {
            CommandGroup(after: .toolbar) {
                ForEach(Theme.allCases, id: \.self) { theme in
                    Button {
                        themeManager.currentTheme = theme
                    } label: {
                        if themeManager.currentTheme == theme {
                            Label(theme.rawValue.capitalized, systemImage: "checkmark")
                        } else {
                            Text(theme.rawValue.capitalized)
                        }
                    }
                    .keyboardShortcut(
                        theme == .classic ? "1" : "2",
                        modifiers: [.command, .shift]
                    )
                }

                Divider()

                Button("Increase Font Size") {
                    coordinator?.increaseFontSize()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Decrease Font Size") {
                    coordinator?.decreaseFontSize()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Reset Font Size") {
                    coordinator?.resetFontSize()
                }
                .keyboardShortcut("0", modifiers: .command)
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

        Settings {
            SettingsView()
                .environment(themeManager)
        }
    }
}
