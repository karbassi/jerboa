import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?
    @StateObject private var coordinator = WebViewCoordinator()
    @State private var fileWatcher: FileWatcher?
    @State private var displayText: String
    @State private var hasPendingUpdate = false
    @AppStorage("sidebarVisible") private var sidebarVisible = true
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(document: Binding<MarkdownDocument>, fileURL: URL?) {
        _document = document
        self.fileURL = fileURL
        _displayText = State(initialValue: document.wrappedValue.text)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            TOCSidebarView(
                entries: coordinator.tocEntries,
                activeHeadingID: coordinator.activeHeadingID,
                fontSize: coordinator.fontSize,
                onSelect: { id in
                    coordinator.scrollToHeading(id)
                }
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
            .accessibilityIdentifier("toc-sidebar")
        } detail: {
            MarkdownWebView(
                markdownText: displayText,
                coordinator: coordinator
            )
            .accessibilityIdentifier("markdown-webview")
            .toolbar {
                if hasPendingUpdate {
                    ToolbarItem(placement: .primaryAction) {
                        FileUpdatedBanner(onReload: reloadFromDisk)
                    }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .focusedSceneValue(\.coordinator, coordinator)
        .onAppear {
            columnVisibility = sidebarVisible ? .all : .detailOnly
            coordinator.documentDirectoryURL = fileURL?.deletingLastPathComponent()
            setupFileWatcher()
            if let fileURL {
                SpotlightIndexer.index(fileURL: fileURL, text: document.text)
            }
        }
        .onDisappear {
            coordinator.tearDown()
            fileWatcher?.stop()
        }
        .onChange(of: columnVisibility) { _, newValue in
            sidebarVisible = (newValue != .detailOnly)
        }
        .background(WindowAccessor())
    }

}

private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.setFrameAutosaveName("JerboaMainWindow")
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension ContentView {
    private func setupFileWatcher() {
        guard let url = fileURL else { return }
        let watcher = FileWatcher(url: url)
        watcher.onChange = {
            hasPendingUpdate = true
        }
        fileWatcher = watcher
    }

    private func reloadFromDisk() {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url, options: .uncached) else {
            hasPendingUpdate = false
            return
        }
        let text = String(data: data, encoding: .utf8)
               ?? String(data: data, encoding: .isoLatin1) ?? ""
        displayText = text
        hasPendingUpdate = false
    }
}

private struct FileUpdatedBanner: View {
    let onReload: () -> Void

    var body: some View {
        Button(action: onReload) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .imageScale(.small)
                Text("New content")
                    .font(.caption)
            }
        }
        .keyboardShortcut("r", modifiers: .command)
        .help("File updated on disk — click to reload (⌘R)")
    }
}
