import Testing
import Foundation
@testable import News_Digest

@MainActor
struct RSSParserTests {
    @Test func parsesRSS2WithCDATAAndEntities() {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0"><channel>
          <item>
            <title>Apple &amp; Google ship &quot;thing&quot;</title>
            <link>https://example.com/a</link>
            <description><![CDATA[<p>Hello <b>world</b> &amp; friends.</p>]]></description>
            <pubDate>Mon, 09 Nov 2026 12:30:00 +0000</pubDate>
          </item>
        </channel></rss>
        """
        let articles = RSSParser.parse(data: Data(xml.utf8), feed: Fixture.feed)

        #expect(articles.count == 1)
        let article = articles[0]
        #expect(article.title == "Apple & Google ship \"thing\"")
        #expect(article.content == "Hello world & friends.")
        #expect(article.url.absoluteString == "https://example.com/a")
        #expect(article.source == "Example Wire")
        #expect(article.category == .tech)
        #expect(article.publishedAt == Date(timeIntervalSince1970: 1_794_227_400))
    }

    @Test func prefersContentEncodedOverDescription() {
        let xml = """
        <rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/"><channel><item>
          <title>T</title><link>https://example.com/t</link>
          <description>short teaser</description>
          <content:encoded><![CDATA[<p>the full story text</p>]]></content:encoded>
        </item></channel></rss>
        """
        let articles = RSSParser.parse(data: Data(xml.utf8), feed: Fixture.feed)
        #expect(articles.first?.content == "the full story text")
    }

    @Test func parsesAtomAndPicksAlternateLink() {
        let xml = """
        <feed xmlns="http://www.w3.org/2005/Atom">
          <entry>
            <title>Atom story</title>
            <link rel="self" href="https://example.com/api/1"/>
            <link rel="alternate" href="https://example.com/story/1"/>
            <link rel="enclosure" href="https://example.com/audio.mp3"/>
            <updated>2026-11-09T12:30:00Z</updated>
            <summary>Summary here</summary>
          </entry>
        </feed>
        """
        let articles = RSSParser.parse(data: Data(xml.utf8), feed: Fixture.feed)

        #expect(articles.count == 1)
        #expect(articles[0].url.absoluteString == "https://example.com/story/1")
        #expect(articles[0].content == "Summary here")
        #expect(articles[0].publishedAt == Date(timeIntervalSince1970: 1_794_227_400))
    }

    @Test func skipsItemsMissingTitleOrUsableLink() {
        let xml = """
        <rss><channel>
          <item><title></title><link>https://example.com/no-title</link></item>
          <item><title>No link</title></item>
          <item><title>Bad scheme</title><link>javascript:alert(1)</link></item>
          <item><title>Good</title><link>https://example.com/good</link></item>
        </channel></rss>
        """
        let articles = RSSParser.parse(data: Data(xml.utf8), feed: Fixture.feed)
        #expect(articles.map(\.title) == ["Good"])
    }

    @Test func fallsBackToTitleWhenNoBody() {
        let xml = "<rss><channel><item><title>Only title</title><link>https://example.com/x</link></item></channel></rss>"
        let articles = RSSParser.parse(data: Data(xml.utf8), feed: Fixture.feed)
        #expect(articles.first?.content == "Only title")
    }

    @Test func malformedXMLDoesNotCrash() {
        let articles = RSSParser.parse(data: Data("<rss><channel><item><title>x".utf8), feed: Fixture.feed)
        #expect(articles.isEmpty)
    }

    @Test(arguments: [
        ("Mon, 09 Nov 2026 12:30:00 +0000", 1_794_227_400.0),
        ("Mon, 09 Nov 2026 12:30:00 GMT", 1_794_227_400.0),
        ("Mon, 09 Nov 2026 07:30:00 -0500", 1_794_227_400.0),
        ("2026-11-09T12:30:00Z", 1_794_227_400.0),
        ("2026-11-09T12:30:00+00:00", 1_794_227_400.0),
        ("2026-11-09T12:30:00.000Z", 1_794_227_400.0),
    ])
    func parsesCommonDateFormats(string: String, expected: Double) {
        #expect(RSSParser.parseDate(string)?.timeIntervalSince1970 == expected)
    }

    @Test func unparseableDateIsNil() {
        #expect(RSSParser.parseDate("yesterday-ish") == nil)
        #expect(RSSParser.parseDate("") == nil)
    }
}
