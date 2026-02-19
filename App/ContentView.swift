import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?
    @StateObject private var coordinator = WebViewCoordinator()
    @Environment(ThemeManager.self) private var themeManager
    @State private var fileWatcher: FileWatcher?

    var body: some View {
        NavigationSplitView {
            TOCSidebarView(
                entries: coordinator.tocEntries,
                activeHeadingID: coordinator.activeHeadingID,
                onSelect: { id in
                    coordinator.scrollToHeading(id)
                }
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
            .accessibilityIdentifier("toc-sidebar")
        } detail: {
            MarkdownWebView(
                markdownText: document.text,
                theme: themeManager.currentTheme.rawValue,
                coordinator: coordinator
            )
            .accessibilityIdentifier("markdown-webview")
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            setupFileWatcher()
        }
        .onDisappear {
            fileWatcher?.stop()
        }
    }

    private func setupFileWatcher() {
        guard let url = fileURL else { return }
        let watcher = FileWatcher(url: url)
        watcher.onChange = { [url] in
            guard let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8) else { return }
            document.text = text
        }
        fileWatcher = watcher
    }
}
