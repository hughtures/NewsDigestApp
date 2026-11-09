import Foundation

struct NewsDigest: Codable, Identifiable {
    let id: UUID
    let date: Date
    let content: String
    let articleCount: Int

    init(
        id: UUID = UUID(),
        date: Date,
        content: String,
        articleCount: Int
    ) {
        self.id = id
        self.date = date
        self.content = content
        self.articleCount = articleCount
    }

    /// Builds a digest and derives `articleCount` from the Markdown itself, so a
    /// freshly generated digest and one reloaded from disk always agree.
    init(date: Date, content: String) {
        self.init(date: date, content: content, articleCount: Self.countArticles(in: content))
    }

    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    var fileName: String {
        "\(Self.fileDateFormatter.string(from: date)).md"
    }

    /// Each article in a digest is a top-level bullet that begins with a bold
    /// headline (`- **Headline**`). Counting those lines is robust to bold text
    /// appearing mid-sentence, which a plain substring search is not.
    static func countArticles(in markdown: String) -> Int {
        markdown
            .split(whereSeparator: \.isNewline)
            .filter { $0.hasPrefix("- **") }
            .count
    }

    static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
