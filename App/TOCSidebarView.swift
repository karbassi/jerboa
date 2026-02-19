import SwiftUI

struct TOCSidebarView: View {
    let entries: [TOCEntry]
    let activeHeadingID: String?
    let fontSize: CGFloat
    let onSelect: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            List(entries) { entry in
                Button {
                    onSelect(entry.id)
                } label: {
                    Text(entry.title)
                        .font(.system(size: fontSize, weight: entry.level == 2 ? .bold : .regular))
                        .foregroundStyle(entry.id == activeHeadingID ? .primary : .secondary)
                        .padding(.leading, entry.level == 3 ? 16 : 0)
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
