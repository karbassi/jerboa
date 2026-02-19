import SwiftUI

struct TOCSidebarView: View {
    let entries: [TOCEntry]
    let activeHeadingID: String?
    let onSelect: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            List(entries) { entry in
                Button {
                    onSelect(entry.id)
                } label: {
                    Text(entry.title)
                        .font(entry.level == 2 ? .body.bold() : .body)
                        .foregroundStyle(entry.id == activeHeadingID ? .primary : .secondary)
                        .padding(.leading, entry.level == 3 ? 16 : 0)
                }
                .buttonStyle(.plain)
                .id(entry.id)
                .accessibilityIdentifier("toc-\(entry.id)")
                .accessibilityValue(entry.id == activeHeadingID ? "active" : "inactive")
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
