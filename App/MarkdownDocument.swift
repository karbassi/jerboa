import SwiftUI
import UniformTypeIdentifiers

struct MarkdownDocument: FileDocument {
    var text: String
    var fileURL: URL?

    static var readableContentTypes: [UTType] {
        [.init(importedAs: "net.daringfireball.markdown"), .plainText]
    }

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if let string = String(data: data, encoding: .utf8) {
            self.text = string
        } else if let string = String(data: data, encoding: .isoLatin1) {
            self.text = string
        } else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.fileWriteNoPermission, userInfo: [
            NSLocalizedDescriptionKey: "Jerboa is a read-only viewer."
        ])
    }
}
