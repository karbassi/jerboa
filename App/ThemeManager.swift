import SwiftUI
import MarkdownRenderer

@Observable
final class ThemeManager {
    static let suiteName = "group.com.karbassi.Jerboa"
    static let themeKey = "jerboa-theme"

    var currentTheme: Theme {
        didSet {
            let defaults = UserDefaults(suiteName: Self.suiteName) ?? .standard
            defaults.set(currentTheme.rawValue, forKey: Self.themeKey)
        }
    }

    init() {
        let defaults = UserDefaults(suiteName: Self.suiteName) ?? .standard
        let stored = defaults.string(forKey: Self.themeKey) ?? Theme.classic.rawValue
        self.currentTheme = Theme(rawValue: stored) ?? .classic
    }
}
