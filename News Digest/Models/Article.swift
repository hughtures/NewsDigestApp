import Foundation

nonisolated struct Article: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let content: String
    let url: URL
    let source: String
    let publishedAt: Date?
    let category: NewsCategory

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        url: URL,
        source: String,
        publishedAt: Date?,
        category: NewsCategory
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.url = url
        self.source = source
        self.publishedAt = publishedAt
        self.category = category
    }
}

/// The subset of an `Article` that is sent to Claude. Kept separate from
/// `Article` so the prompt payload is explicit and independently testable.
nonisolated struct ArticlePayload: Encodable, Equatable {
    let title: String
    let content: String
    let url: String
    let source: String
    let publishedAt: String?

    init(_ article: Article, maxContentLength: Int = 600) {
        title = article.title
        content = String(article.content.prefix(maxContentLength))
        url = article.url.absoluteString
        source = article.source
        publishedAt = article.publishedAt.map { ISO8601DateFormatter().string(from: $0) }
    }
}
