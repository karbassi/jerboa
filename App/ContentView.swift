import SwiftUI

enum DocumentSyncState {
    case reading        // rendered Document matches the file on disk
    case pendingReload  // file changed on disk after the last render
    case missing        // file is no longer at its path; terminal until re-opened
}

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?
    @StateObject private var coordinator = WebViewCoordinator()
    @State private var fileWatcher: FileWatcher?
    @State private var displayText: String
    @State private var syncState: DocumentSyncState = .reading
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
                if syncState == .pendingReload {
                    ToolbarItem(placement: .primaryAction) {
                        PendingReloadIndicator(onReload: reloadFromDisk)
                    }
                }
            }
        }
        .background(MissingTitlebarAccessory(isVisible: syncState == .missing))
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

private struct MissingTitlebarAccessory: NSViewRepresentable {
    let isVisible: Bool

    private static let identifier = NSUserInterfaceItemIdentifier("JerboaMissingTitlebarAccessory")

    final class Coordinator {
        var controller: NSTitlebarAccessoryViewController?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            sync(window: view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            sync(window: nsView.window, coordinator: context.coordinator)
        }
    }

    private func sync(window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }
        if isVisible {
            if coordinator.controller == nil {
                let hosting = NSHostingView(rootView:
                    Text("File missing")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                )
                hosting.frame.size = hosting.fittingSize
                let vc = NSTitlebarAccessoryViewController()
                vc.identifier = Self.identifier
                vc.layoutAttribute = .right
                vc.view = hosting
                window.addTitlebarAccessoryViewController(vc)
                coordinator.controller = vc
            }
        } else if let vc = coordinator.controller {
            if let index = window.titlebarAccessoryViewControllers.firstIndex(of: vc) {
                window.removeTitlebarAccessoryViewController(at: index)
            }
            coordinator.controller = nil
        }
    }
}

extension ContentView {
    private func setupFileWatcher() {
        guard let url = fileURL else { return }
        guard let watcher = FileWatcher(url: url) else {
            syncState = .missing
            return
        }
        watcher.onEvent = { event in
            switch event {
            case .changed:
                if syncState != .missing { syncState = .pendingReload }
            case .vanished:
                syncState = .missing
            }
        }
        fileWatcher = watcher
    }

    private func reloadFromDisk() {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url, options: .uncached) else {
            syncState = .missing
            return
        }
        let text = String(data: data, encoding: .utf8)
               ?? String(data: data, encoding: .isoLatin1) ?? ""
        displayText = text
        syncState = .reading
    }
}

private struct PendingReloadIndicator: View {
    let onReload: () -> Void

    var body: some View {
        Button(action: onReload) {
            Text("New content")
                .font(.caption)
        }
        .keyboardShortcut("r", modifiers: .command)
        .help("File updated on disk — click to reload (⌘R)")
    }
}

