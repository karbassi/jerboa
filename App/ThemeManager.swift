import SwiftUI
import MarkdownRenderer

@Observable
final class ThemeManager {
    var currentTheme: Theme {
        didSet {
            storedTheme = currentTheme.rawValue
        }
    }

    @ObservationIgnored
    @AppStorage("jerboa-theme") private var storedTheme: String = Theme.classic.rawValue

    init() {
        let stored = UserDefaults.standard.string(forKey: "jerboa-theme") ?? Theme.classic.rawValue
        self.currentTheme = Theme(rawValue: stored) ?? .classic
    }
}
