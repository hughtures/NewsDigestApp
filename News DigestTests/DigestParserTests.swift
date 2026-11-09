import Testing
import Foundation
@testable import News_Digest

struct DigestParserTests {
    let sample = """
    # Daily News Digest – November 9, 2026

    ## 🔴 Top Stories
    - **Storm Hits Coast**
      A powerful storm made landfall. Crews expect repairs within 48 hours.
      🔗 *Source: Sample Wire* - https://example.com/storm
    - **Rail Expansion Approved**
      The board voted 9–2.
      🔗 *Source: BBC World News* - https://example.com/rail.

    ## 💻 Technology
    - **Chip Unveiled**
      Efficiency gains of 3x.
      🔗 *Source: Tech Daily* - https://example.com/chip
    """

    @Test func groupsMultiLineBulletsIntoArticles() {
        let elements = DigestParser.parse(sample)
        let articles = elements.compactMap { element -> DigestArticle? in
            if case .article(let a) = element { return a } else { return nil }
        }

        #expect(articles.count == 3)
        #expect(articles[0].title == "Storm Hits Coast")
        #expect(articles[0].summary == "A powerful storm made landfall. Crews expect repairs within 48 hours.")
        #expect(articles[0].sourceName == "Sample Wire")
        #expect(articles[0].url?.absoluteString == "https://example.com/storm")
    }

    @Test func stripsTrailingPunctuationFromURLs() {
        let elements = DigestParser.parse(sample)
        guard case .article(let rail) = elements[3] else { Issue.record("expected article"); return }
        #expect(rail.url?.absoluteString == "https://example.com/rail")
        #expect(rail.sourceName == "BBC World News")
    }

    @Test func emitsTitleAndSectionsInOrder() {
        let elements = DigestParser.parse(sample)
        #expect(elements.first == .title("Daily News Digest – November 9, 2026"))
        #expect(elements.contains(.section("🔴 Top Stories")))
        #expect(elements.contains(.section("💻 Technology")))
    }

    @Test func articleCountMatchesNewsDigestCounter() {
        let parsed = DigestParser.parse(sample).filter { if case .article = $0 { true } else { false } }.count
        #expect(parsed == NewsDigest.countArticles(in: sample))
    }

    @Test func handlesSingleLineLegacyItems() {
        let md = "- **Headline** Short summary. 🔗 *Source: A* - https://a.example/x"
        guard case .article(let a)? = DigestParser.parse(md).first else { Issue.record("expected article"); return }
        #expect(a.title == "Headline")
        #expect(a.url?.absoluteString == "https://a.example/x")
    }

    @Test func plainParagraphsSurvive() {
        #expect(DigestParser.parse("No significant news stories identified today.") ==
                [.paragraph("No significant news stories identified today.")])
    }

    @Test func articleWithoutLinkStillParses() {
        guard case .article(let a)? = DigestParser.parse("- **Only title**\n  Just words.").first else { Issue.record("expected article"); return }
        #expect(a.url == nil)
        #expect(a.summary == "Just words.")
    }
}
