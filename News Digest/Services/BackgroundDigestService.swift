import os
import Foundation
import UserNotifications

enum DigestError: LocalizedError {
    case noFeeds
    case noArticles
    case alreadyRunning

    var errorDescription: String? {
        switch self {
        case .noFeeds: return "No RSS feeds configured. Add some in Settings → Feeds."
        case .noArticles: return "No recent articles were found in your feeds."
        case .alreadyRunning: return "A digest is already being generated."
        }
    }
}

/// Orchestrates one digest run: load settings → fetch feeds → ask Claude →
/// save to disk → notify. `@MainActor` serialises runs so two triggers (e.g. the
/// schedule and the menu) can never overlap.
@MainActor
final class BackgroundDigestService {
    static let shared = BackgroundDigestService()

    private var isGenerating = false

    private init() {
        requestNotificationPermission()
    }

    /// Generates and saves today's digest.
    @discardableResult
    func generateDigest() async throws -> NewsDigest {
        guard !isGenerating else { throw DigestError.alreadyRunning }
        isGenerating = true
        defer { isGenerating = false }

        do {
            let digest = try await run()
            await notify(title: "📰 NewsDigest Ready",
                         body: "Your daily digest is ready with \(digest.articleCount) stories.")
            return digest
        } catch {
            Log.digest.error("Digest failed: \(error.localizedDescription, privacy: .public)")
            if case DigestError.alreadyRunning = error {} else {
                await notify(title: "⚠️ NewsDigest Error", body: error.localizedDescription)
            }
            throw error
        }
    }

    /// Fire-and-forget entry point for menu items.
    func generateDigestInBackground() {
        Task {
            await DigestViewModel.shared.generateDigest()
        }
    }

    private func run() async throws -> NewsDigest {
        var settings = StorageService.shared.loadSettings()
        if settings.feedSources.isEmpty {
            settings.feedSources = StorageService.shared.loadDefaultFeeds()
        }
        guard !settings.feedSources.isEmpty else { throw DigestError.noFeeds }

        Log.digest.info("Fetching \(settings.feedSources.count) feeds")
        let fetched = await RSSFeedService.shared.fetchArticles(from: settings.feedSources)
        let articles = RSSFeedService.select(from: fetched)
        guard !articles.isEmpty else { throw DigestError.noArticles }
        Log.digest.info("Sending \(articles.count) of \(fetched.count) fetched articles to Claude")

        let dateString = Date().formatted(.dateTime.month(.wide).day().year())
        let markdown = try await withRetry(
            maxAttempts: 3,
            delay: 5,
            shouldRetry: { ($0 as? AnthropicError)?.isRetryable ?? ($0 is URLError) }
        ) {
            try await AnthropicService.shared.generateDigest(articles: articles, date: dateString)
        }

        let digest = NewsDigest(date: Date(), content: markdown)
        try StorageService.shared.saveDigest(digest)

        settings.lastDigestDate = Date()
        StorageService.shared.saveSettings(settings)
        return digest
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                Log.digest.error("Notification permission error: \(error.localizedDescription, privacy: .public)")
            } else {
                Log.digest.info("Notification permission granted: \(granted)")
            }
        }
    }

    private func notify(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
