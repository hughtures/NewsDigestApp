import os
import Foundation

nonisolated final class RSSFeedService {
    static let shared = RSSFeedService()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches every enabled feed concurrently. A feed that fails is logged and
    /// skipped so one broken source can't sink the whole digest.
    func fetchArticles(from feeds: [FeedSource]) async -> [Article] {
        let enabledFeeds = feeds.filter(\.isEnabled)

        return await withTaskGroup(of: [Article].self) { group in
            for feed in enabledFeeds {
                group.addTask {
                    do {
                        return try await self.fetchFeed(feed)
                    } catch {
                        Log.feeds.error("Failed to fetch \(feed.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        return []
                    }
                }
            }

            var all: [Article] = []
            for await articles in group {
                all.append(contentsOf: articles)
            }
            return all
        }
    }

    private func fetchFeed(_ feed: FeedSource) async throws -> [Article] {
        var request = URLRequest(url: feed.url)
        request.timeoutInterval = 20
        let (data, _) = try await session.data(for: request)
        return RSSParser.parse(data: data, feed: feed)
    }

    /// Trims a raw haul of articles down to what's worth sending to Claude:
    /// removes duplicate URLs, drops stale items, and caps each feed so one
    /// chatty source can't crowd out the others (or blow up the token bill).
    static func select(
        from articles: [Article],
        perFeedLimit: Int = 12,
        maxAge: TimeInterval = 36 * 60 * 60,
        now: Date = Date()
    ) -> [Article] {
        var seenURLs = Set<URL>()
        var perSourceCount: [String: Int] = [:]

        let newestFirst = articles.sorted {
            ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast)
        }

        return newestFirst.filter { article in
            if let published = article.publishedAt, now.timeIntervalSince(published) > maxAge {
                return false
            }
            guard seenURLs.insert(article.url).inserted else { return false }

            let count = perSourceCount[article.source, default: 0]
            guard count < perFeedLimit else { return false }
            perSourceCount[article.source] = count + 1
            return true
        }
    }
}
