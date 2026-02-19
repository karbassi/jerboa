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
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.fileWriteNoPermission)
    }
}
