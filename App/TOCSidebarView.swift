import MarkdownRenderer
import SwiftUI

struct TOCSidebarView: View {
    let entries: [Heading]
    let activeHeadingID: String?
    let fontSize: CGFloat
    let onSelect: (String) -> Void

    /// Shallowest heading level present, used as the indentation reference.
    /// A doc with only h2/h3 indents h2 at 0; a doc with h1/h2/h3 indents h1 at 0.
    private var minLevel: Int { entries.map(\.level).min() ?? 1 }

    private func weight(for level: Int) -> Font.Weight {
        level == minLevel ? .bold : .regular
    }

    private func indent(for level: Int) -> CGFloat {
        CGFloat(max(0, level - minLevel)) * 12
    }

    var body: some View {
        ScrollViewReader { proxy in
            List(entries) { entry in
                Button {
                    onSelect(entry.id)
                } label: {
                    Text(entry.title)
                        .font(.system(size: fontSize, weight: weight(for: entry.level)))
                        .foregroundStyle(entry.id == activeHeadingID ? .primary : .secondary)
                        .padding(.leading, indent(for: entry.level))
                }
                .buttonStyle(.plain)
                .id(entry.id)
                .accessibilityIdentifier("toc-\(entry.id)")
                .accessibilityValue(entry.id == activeHeadingID ? "active" : "inactive")
                .contextMenu {
                    Button("Scroll to Heading") {
                        onSelect(entry.id)
                    }
                    Button("Copy Heading Title") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.title, forType: .string)
                    }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: activeHeadingID) { _, newValue in
                if let id = newValue {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }
}
