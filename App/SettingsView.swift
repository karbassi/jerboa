import SwiftUI
import MarkdownRenderer

struct SettingsView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        @Bindable var themeManager = themeManager
        Form {
            Picker("Theme", selection: $themeManager.currentTheme) {
                ForEach(Theme.allCases, id: \.self) { theme in
                    Text(theme.rawValue.capitalized).tag(theme)
                }
            }
            .pickerStyle(.radioGroup)
        }
        .formStyle(.grouped)
        .frame(width: 300, height: 100)
    }
}
