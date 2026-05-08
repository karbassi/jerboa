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
            .overlay(alignment: .top) {
                if hasPendingUpdate {
                    FileUpdatedBanner(onReload: reloadFromDisk)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: hasPendingUpdate)
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
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.secondary)
                Text("File updated on disk — click to reload")
                    .font(.callout)
                Spacer(minLength: 0)
                Text("⌘R")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("r", modifiers: .command)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .help("Reload file from disk (⌘R)")
    }
}
