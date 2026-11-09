import os
import Foundation

enum AnthropicError: LocalizedError, Equatable {
    case noAPIKey
    case invalidResponse
    case apiError(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key found. Please add your Anthropic API key in Settings."
        case .invalidResponse:
            return "Invalid response from Claude API."
        case .apiError(let status, let message):
            return "API Error (\(status)): \(message)"
        }
    }

    /// Whether trying again could plausibly succeed. Bad keys and malformed
    /// requests will not fix themselves; rate limits and outages usually do.
    var isRetryable: Bool {
        switch self {
        case .noAPIKey, .invalidResponse:
            return false
        case .apiError(let status, _):
            return status == 408 || status == 429 || status >= 500
        }
    }
}

/// Anything that can supply the user's API key. `StorageService` (Keychain) is
/// the real implementation; tests inject a stub.
protocol APIKeyProviding {
    func loadAPIKey() -> String?
}

extension StorageService: APIKeyProviding {}

// MARK: - Wire format

struct MessagesRequest: Encodable, Equatable {
    struct Message: Encodable, Equatable {
        let role: String
        let content: String
    }

    let model: String
    let maxTokens: Int
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

struct MessagesResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }

    let content: [ContentBlock]

    /// Concatenated text of every text block in the reply.
    var text: String {
        content.compactMap { $0.type == "text" ? $0.text : nil }.joined()
    }
}

private struct APIErrorEnvelope: Decodable {
    struct Detail: Decodable { let message: String }
    let error: Detail
}

// MARK: - Service

final class AnthropicService {
    static let shared = AnthropicService()

    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let apiVersion = "2023-06-01"

    private let session: URLSession
    private let keyProvider: APIKeyProviding
    private let modelProvider: () -> String

    init(
        session: URLSession = .shared,
        keyProvider: APIKeyProviding = StorageService.shared,
        modelProvider: @escaping () -> String = { StorageService.shared.loadSettings().model }
    ) {
        self.session = session
        self.keyProvider = keyProvider
        self.modelProvider = modelProvider
    }

    /// Asks Claude to turn a batch of articles into the Markdown digest.
    func generateDigest(articles: [Article], date: String) async throws -> String {
        let prompt = Self.buildPrompt(articles: articles, date: date)
        return try await send(prompt: prompt, maxTokens: 4096)
    }

    /// Cheapest possible round trip, used by Settings → "Test Connection".
    func testConnection() async throws {
        _ = try await send(prompt: "Reply with the single word: ok", maxTokens: 16)
    }

    // MARK: Request / response (internal for testing)

    func makeRequest(prompt: String, maxTokens: Int) throws -> URLRequest {
        guard let apiKey = keyProvider.loadAPIKey(), !apiKey.isEmpty else {
            throw AnthropicError.noAPIKey
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = MessagesRequest(
            model: modelProvider(),
            maxTokens: maxTokens,
            messages: [.init(role: "user", content: prompt)]
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    static func parseResponse(data: Data, response: URLResponse) throws -> String {
        guard let http = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }

        guard http.statusCode == 200 else {
            let message = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data))?.error.message
                ?? "HTTP \(http.statusCode)"
            throw AnthropicError.apiError(status: http.statusCode, message: message)
        }

        guard let decoded = try? JSONDecoder().decode(MessagesResponse.self, from: data),
              !decoded.text.isEmpty else {
            throw AnthropicError.invalidResponse
        }
        return decoded.text
    }

    private func send(prompt: String, maxTokens: Int) async throws -> String {
        let request = try makeRequest(prompt: prompt, maxTokens: maxTokens)
        Log.api.info("POST messages (model: \(self.modelProvider(), privacy: .public))")

        let (data, response) = try await session.data(for: request)
        return try Self.parseResponse(data: data, response: response)
    }

    // MARK: Prompt

    static func encodeArticles(_ articles: [Article]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let payload = articles.map { ArticlePayload($0) }
        guard let data = try? encoder.encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    static func buildPrompt(articles: [Article], date: String) -> String {
        let jsonString = encodeArticles(articles)

        return """
        # ROLE
        You are a professional news analyst creating a daily digest of significant news stories.

        # TASK
        Analyze the provided articles and produce a concise, high-quality news digest following the exact specifications below.

        # OUTPUT STRUCTURE

        Start your response directly with:

        # Daily News Digest – \(date)

        ## 🔴 Top Stories
        [Top 3-5 most urgent/important breaking stories and major headlines]

        ## 💻 Technology
        [Top tech industry news, product launches, company developments]

        ## 🤖 Artificial Intelligence
        [AI developments, breakthroughs, industry news, regulations]

        ## 🇺🇸 US Politics
        [Political news, policy changes, elections, government actions]

        ## 🎬 Film & Television
        [Entertainment industry news, releases, streaming, box office]

        **Note**: If a category has no articles meeting quality standards, omit that section entirely.

        # SELECTION CRITERIA

        Include an article ONLY if it passes ALL three filters:

        1. **Impact Test**: Does this affect >10,000 people OR a major industry/institution?
        2. **Novelty Test**: Is this new information (not recycled coverage of ongoing situations)?
        3. **Longevity Test**: Will people still reference this story in 30 days?

        **Exclude**:
        - Celebrity gossip without broader cultural/business significance
        - Clickbait or sensationalized non-news
        - Minor product updates or routine announcements
        - Duplicate coverage of the same event
        - Incremental updates to ongoing stories (unless materially new)

        # ARTICLE FORMAT

        Use this exact structure for each article:

        - **[Rewrite headline to be clear and specific]**
          [Sentence 1: What happened] [Sentence 2: Why it matters or impact] [Sentence 3: Key detail or context - optional]
          🔗 *Source: [Publication Name]* - [URL]

        **Example**:

        - **Federal Reserve Holds Interest Rates at 5.5% Despite Inflation Concerns**
          The Fed maintained its benchmark rate for the third consecutive meeting, citing mixed economic signals. Chair Powell indicated rates may stay elevated through Q2 2024 as core inflation remains above the 2% target. Markets responded positively with the S&P 500 gaining 1.2%.
          🔗 *Source: Wall Street Journal* - https://wsj.com/...

        **Formatting Rules**:
        - Rewrite headlines for clarity (avoid clickbait phrasing)
        - Keep explanations to 2-3 sentences maximum
        - Use neutral, professional tone
        - Every article MUST include publication name and URL

        # PROCESSING INSTRUCTIONS

        Follow these steps in order:

        1. **Read all articles** in the input completely
        2. **Identify duplicates**: Group articles covering the same event
        3. **Apply selection criteria**: Filter out articles that fail any of the three tests
        4. **Consolidate duplicates**: For each story, select the source with most factual detail
        5. **Categorize**: Assign each article to the most appropriate section (if unclear, categorize by primary impact)
        6. **Rank**: Order articles within each category by significance and impact
        7. **Draft**: Write the digest starting with the highest-impact category
        8. **Length check**: If over 4,000 characters, remove lowest-priority articles
        9. **Quality review**: Run final checks (see below)

        # CATEGORIZATION GUIDANCE

        When category placement is ambiguous:
        - "AI regulation bill" → US Politics (policy impact is primary)
        - "OpenAI announces new model" → Artificial Intelligence (tech development is primary)
        - "Netflix AI-powered recommendations" → Technology (business story, not AI breakthrough)
        - "Congressional hearing on tech monopolies" → US Politics (policy/regulatory focus)

        # QUALITY CHECKS

        Before finalizing, verify:

        ✓ No duplicate stories across sections
        ✓ Every article has source name and URL
        ✓ Headlines are rewritten (not copy-pasted from source)
        ✓ Total length is 2,500-4,000 characters
        ✓ Minimum 2-3 articles total (unless legitimately no worthy news)
        ✓ No marketing language, hype, or sensationalism
        ✓ No preamble before digest title
        ✓ No commentary after final article

        # SPECIAL CASES

        - **No qualifying articles**: Output exactly this:
          # Daily News Digest – \(date)

          No significant news stories identified today.

        - **Same event, multiple sources**: Choose the article with most specific facts and newest information

        - **Borderline articles**: When in doubt, exclude. Quality over quantity.

        # INPUT DATA

        The following JSON contains articles to analyze. Each article has:
        - title: string (original headline)
        - content: string (article text or excerpt)
        - url: string (source link)
        - source: string (publication name)
        - publishedAt: timestamp (optional)

        \(jsonString)

        ---

        **Begin your response directly with the digest title. No preamble.**
        """
    }
}
