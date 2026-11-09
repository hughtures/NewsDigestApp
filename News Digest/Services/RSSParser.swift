import Foundation

/// Minimal RSS 2.0 / Atom parser built on `XMLParser`.
nonisolated final class RSSParser: NSObject, XMLParserDelegate {
    private let feedSource: FeedSource
    private(set) var articles: [Article] = []

    private var currentTitle = ""
    private var currentContent = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var isInItem = false
    private var characterBuffer = ""

    private init(feedSource: FeedSource) {
        self.feedSource = feedSource
    }

    static func parse(data: Data, feed: FeedSource) -> [Article] {
        let delegate = RSSParser(feedSource: feed)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.articles
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        characterBuffer = ""

        if elementName == "item" || elementName == "entry" {
            isInItem = true
            currentTitle = ""
            currentContent = ""
            currentLink = ""
            currentPubDate = ""
        }

        // Atom: <link rel="alternate" href="..."/>. Entries often carry several
        // links (self, enclosure, replies); only the "alternate" one is the page.
        if elementName == "link", isInItem, let href = attributeDict["href"] {
            let rel = attributeDict["rel"] ?? "alternate"
            if rel == "alternate" { currentLink = href }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        characterBuffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        characterBuffer += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        defer { characterBuffer = "" }
        guard isInItem else { return }

        let text = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "title":
            currentTitle = text.decodingHTMLEntities
        case "description", "content", "content:encoded", "summary":
            if currentContent.isEmpty || elementName == "content:encoded" {
                currentContent = text.strippingHTML
            }
        case "link":
            if currentLink.isEmpty { currentLink = text }
        case "pubDate", "published", "updated", "dc:date":
            if currentPubDate.isEmpty || elementName != "updated" { currentPubDate = text }
        case "item", "entry":
            appendArticle()
            isInItem = false
        default:
            break
        }
    }

    // MARK: - Helpers

    private func appendArticle() {
        guard !currentTitle.isEmpty,
              let url = URL(string: currentLink), url.scheme?.hasPrefix("http") == true else {
            return
        }

        articles.append(Article(
            title: currentTitle,
            content: currentContent.isEmpty ? currentTitle : currentContent,
            url: url,
            source: feedSource.name,
            publishedAt: Self.parseDate(currentPubDate),
            category: feedSource.category
        ))
    }

    static func parseDate(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: string) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }

        // RFC 822 variants: with/without weekday, seconds, numeric or named zone.
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "EEE, dd MMM yyyy HH:mm Z",
            "dd MMM yyyy HH:mm:ss Z"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}
