import SwiftUI
import MarkdownRenderer

@main
struct JerboaApp: App {
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
                .environment(themeManager)
        }
        .commands {
            CommandMenu("Theme") {
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
            }
        }
    }
}
