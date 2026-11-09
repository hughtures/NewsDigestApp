import Testing
import Foundation
@testable import News_Digest

@MainActor
struct ModelTests {
    // MARK: NewsDigest

    @Test func countsOnlyTopLevelBoldBullets() {
        let markdown = """
        # Daily News Digest – November 9, 2026

        ## 💻 Technology
        - **First headline**
          Something **important** happened. Why it matters.
          🔗 *Source: A* - https://a.example
        - **Second headline**
          More.
          🔗 *Source: B* - https://b.example
        """
        #expect(NewsDigest.countArticles(in: markdown) == 2)
    }

    @Test func emptyDigestHasNoArticles() {
        #expect(NewsDigest.countArticles(in: "# Daily News Digest – x\n\nNo significant news stories identified today.") == 0)
    }

    @Test func fileNameIsStableISODate() {
        let date = DateComponents(calendar: .current, year: 2026, month: 3, day: 7, hour: 12).date!
        #expect(NewsDigest(date: date, content: "").fileName == "2026-03-07.md")
    }

    @Test func convenienceInitDerivesArticleCount() {
        let digest = NewsDigest(date: Date(), content: "- **One**\n- **Two**\n")
        #expect(digest.articleCount == 2)
    }

    // MARK: AppSettings

    @Test func decodesLegacySettingsWithoutModelKey() throws {
        // Settings saved before the `model` field existed must keep their feeds.
        let feed = Fixture.feed
        let feedJSON = String(data: try JSONEncoder().encode(feed), encoding: .utf8)!
        let legacy = """
        {"feedSources":[\(feedJSON)],"scheduleTime":{"hour":7,"minute":15},"isScheduleEnabled":false}
        """
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(legacy.utf8))

        #expect(settings.feedSources == [feed])
        #expect(settings.scheduleTime.hour == 7)
        #expect(settings.isScheduleEnabled == false)
        #expect(settings.model == ClaudeModel.default.rawValue)
    }

    @Test func settingsRoundTrip() throws {
        let original = AppSettings(feedSources: [Fixture.feed], scheduleTime: DateComponents(hour: 5, minute: 45),
                                   isScheduleEnabled: true, lastDigestDate: Date(timeIntervalSince1970: 1000),
                                   model: ClaudeModel.opus.rawValue)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test func defaultFeedsFileDecodes() throws {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "DefaultFeeds", withExtension: "json")
                               ?? Bundle.main.url(forResource: "DefaultFeeds", withExtension: "json"))
        let feeds = try JSONDecoder().decode([FeedSource].self, from: Data(contentsOf: url))
        #expect(feeds.count == 15)
        #expect(Set(feeds.map(\.category)) == Set(NewsCategory.allCases))
    }

    // MARK: ArticlePayload

    @Test func payloadTruncatesLongContent() {
        let article = Fixture.article(content: String(repeating: "x", count: 5000))
        #expect(ArticlePayload(article).content.count == 600)
    }
}

private final class BundleToken {}
