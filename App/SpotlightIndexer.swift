import CoreSpotlight

enum SpotlightIndexer {
    static func index(fileURL: URL, text: String) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .plainText)
        attributeSet.title = fileURL.lastPathComponent
        attributeSet.contentDescription = String(text.prefix(500))

        let item = CSSearchableItem(
            uniqueIdentifier: fileURL.absoluteString,
            domainIdentifier: "com.karbassi.Jerboa.markdown",
            attributeSet: attributeSet
        )

        CSSearchableIndex.default().indexSearchableItems([item])
    }
}
