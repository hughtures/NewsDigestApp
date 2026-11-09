import Foundation

nonisolated struct FeedSource: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var url: URL
    let category: NewsCategory
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        category: NewsCategory,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.category = category
        self.isEnabled = isEnabled
    }
}
