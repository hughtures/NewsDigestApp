import Testing
import Foundation
@testable import News_Digest

@MainActor
@Suite(.serialized)
struct AnthropicServiceTests {
    func service(key: String? = "sk-ant-test", model: String = "claude-sonnet-5-5") -> AnthropicService {
        AnthropicService(session: StubURLProtocol.session(), keyProvider: StubKeyProvider(key: key), modelProvider: { model })
    }

    // MARK: Request construction

    @Test func buildsAuthenticatedJSONRequest() throws {
        let request = try service(model: "claude-haiku-5-5").makeRequest(prompt: "hi", maxTokens: 123)

        #expect(request.url == AnthropicService.endpoint)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-ant-test")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "content-type") == "application/json")

        let body = try JSONSerialization.jsonObject(with: #require(request.httpBody)) as? [String: Any]
        #expect(body?["model"] as? String == "claude-haiku-5-5")
        #expect(body?["max_tokens"] as? Int == 123)
        let messages = body?["messages"] as? [[String: String]]
        #expect(messages == [["role": "user", "content": "hi"]])
    }

    @Test func missingOrEmptyKeyThrowsNoAPIKey() {
        #expect(throws: AnthropicError.noAPIKey) { try service(key: nil).makeRequest(prompt: "x", maxTokens: 1) }
        #expect(throws: AnthropicError.noAPIKey) { try service(key: "").makeRequest(prompt: "x", maxTokens: 1) }
    }

    // MARK: Response parsing

    @Test func parsesTextBlocks() throws {
        let json = #"{"content":[{"type":"text","text":"Hello "},{"type":"text","text":"world"}]}"#
        let text = try AnthropicService.parseResponse(data: Data(json.utf8), response: StubURLProtocol.response(status: 200))
        #expect(text == "Hello world")
    }

    @Test func surfacesAPIErrorMessage() {
        let json = #"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#
        #expect(throws: AnthropicError.apiError(status: 401, message: "invalid x-api-key")) {
            try AnthropicService.parseResponse(data: Data(json.utf8), response: StubURLProtocol.response(status: 401))
        }
    }

    @Test func nonJSONErrorFallsBackToStatusCode() {
        #expect(throws: AnthropicError.apiError(status: 502, message: "HTTP 502")) {
            try AnthropicService.parseResponse(data: Data("<html>bad gateway</html>".utf8), response: StubURLProtocol.response(status: 502))
        }
    }

    @Test func emptyOrUnexpectedBodyIsInvalid() {
        #expect(throws: AnthropicError.invalidResponse) {
            try AnthropicService.parseResponse(data: Data(#"{"content":[]}"#.utf8), response: StubURLProtocol.response(status: 200))
        }
        #expect(throws: AnthropicError.invalidResponse) {
            try AnthropicService.parseResponse(data: Data("nope".utf8), response: StubURLProtocol.response(status: 200))
        }
    }

    @Test(arguments: [(401, false), (400, false), (404, false), (408, true), (429, true), (500, true), (529, true)])
    func retryability(status: Int, retryable: Bool) {
        #expect(AnthropicError.apiError(status: status, message: "").isRetryable == retryable)
    }

    // MARK: End to end through a stubbed URLSession

    @Test func generateDigestReturnsModelText() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-ant-test")
            return (StubURLProtocol.response(status: 200), Data(##"{"content":[{"type":"text","text":"# Daily News Digest"}]}"##.utf8))
        }
        defer { StubURLProtocol.handler = nil }

        let text = try await service().generateDigest(articles: [Fixture.article("Big news")], date: "November 9, 2026")
        #expect(text == "# Daily News Digest")
    }

    @Test func testConnectionPropagatesAuthFailure() async {
        StubURLProtocol.handler = { _ in
            (StubURLProtocol.response(status: 401), Data(#"{"error":{"message":"invalid x-api-key"}}"#.utf8))
        }
        defer { StubURLProtocol.handler = nil }

        await #expect(throws: AnthropicError.apiError(status: 401, message: "invalid x-api-key")) {
            try await service().testConnection()
        }
    }

    // MARK: Prompt

    @Test func promptEmbedsDateAndArticleJSON() {
        let prompt = AnthropicService.buildPrompt(
            articles: [Fixture.article("Chip maker unveils processor", url: "https://example.com/chips")],
            date: "November 9, 2026"
        )
        #expect(prompt.contains("# Daily News Digest – November 9, 2026"))
        #expect(prompt.contains("\"title\" : \"Chip maker unveils processor\""))
        #expect(prompt.contains("https://example.com/chips"))   // slashes must not be escaped
        #expect(!prompt.contains("\\/"))
    }

    @Test func encodedArticlesAreStableAndValidJSON() throws {
        let json = AnthropicService.encodeArticles([Fixture.article("One"), Fixture.article("Two")])
        let array = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]]
        #expect(array?.count == 2)
        #expect(array?.first?.keys.sorted() == ["content", "publishedAt", "source", "title", "url"])
        #expect(AnthropicService.encodeArticles([]) == "[\n\n]")
    }
}
