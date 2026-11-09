import Testing
import Foundation
@testable import News_Digest

struct ArticleSelectionTests {
    let now = Date(timeIntervalSince1970: 1_794_227_400)

    @Test func dropsDuplicateURLs() {
        let a = Fixture.article("A", url: "https://example.com/same", now: now)
        let b = Fixture.article("B", url: "https://example.com/same", source: "Other", now: now)
        let selected = RSSFeedService.select(from: [a, b], now: now)
        #expect(selected.count == 1)
    }

    @Test func dropsArticlesOlderThanMaxAge() {
        let fresh = Fixture.article("Fresh", age: 3 * 3600, now: now)
        let stale = Fixture.article("Stale", age: 48 * 3600, now: now)
        let selected = RSSFeedService.select(from: [stale, fresh], maxAge: 36 * 3600, now: now)
        #expect(selected.map(\.title) == ["Fresh"])
    }

    @Test func keepsArticlesWithUnknownDate() {
        let undated = Article(title: "Undated", content: "c", url: URL(string: "https://example.com/u")!,
                              source: "S", publishedAt: nil, category: .tech)
        #expect(RSSFeedService.select(from: [undated], now: now).count == 1)
    }

    @Test func capsEachFeedKeepingNewest() {
        let articles = (0..<10).map {
            Fixture.article("Story \($0)", age: Double($0) * 600, now: now)
        }
        let selected = RSSFeedService.select(from: articles, perFeedLimit: 3, now: now)
        #expect(selected.map(\.title) == ["Story 0", "Story 1", "Story 2"])
    }

    @Test func capIsPerSourceNotGlobal() {
        let a = (0..<5).map { Fixture.article("A\($0)", source: "A", age: Double($0), now: now) }
        let b = (0..<5).map { Fixture.article("B\($0)", source: "B", age: Double($0), now: now) }
        #expect(RSSFeedService.select(from: a + b, perFeedLimit: 2, now: now).count == 4)
    }

    @Test func resultIsNewestFirst() {
        let old = Fixture.article("Old", age: 7200, now: now)
        let new = Fixture.article("New", age: 60, now: now)
        #expect(RSSFeedService.select(from: [old, new], now: now).map(\.title) == ["New", "Old"])
    }
}
