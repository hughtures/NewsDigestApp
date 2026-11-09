import Foundation
@testable import News_Digest

enum Fixture {
    static let feed = FeedSource(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
        name: "Example Wire",
        url: URL(string: "https://example.com/rss")!,
        category: .tech
    )

    static func article(
        _ title: String = "Headline",
        url: String? = nil,
        source: String = "Example Wire",
        age: TimeInterval = 3600,
        now: Date = Date(),
        content: String = "Body text."
    ) -> Article {
        Article(
            title: title,
            content: content,
            url: URL(string: url ?? "https://example.com/\(title.replacingOccurrences(of: " ", with: "-"))")!,
            source: source,
            publishedAt: now.addingTimeInterval(-age),
            category: .tech
        )
    }
}

struct StubKeyProvider: APIKeyProviding {
    var key: String?
    func loadAPIKey() -> String? { key }
}

/// Intercepts `URLSession` traffic so API tests never touch the network.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    static func response(status: Int, url: URL = AnthropicService.endpoint) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
}
