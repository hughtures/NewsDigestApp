import Foundation
import SwiftUI
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var feedSources: [FeedSource] = []
    @Published var scheduleTime: DateComponents = DateComponents(hour: 6, minute: 0)
    @Published var isScheduleEnabled: Bool = true
    @Published var model: String = ClaudeModel.default.rawValue
    @Published var isTestingAPIKey: Bool = false
    @Published var apiKeyTestResult: String?
    private var lastDigestDate: Date?

    init() {
        loadSettings()
        loadAPIKey()
    }

    func loadSettings() {
        let settings = StorageService.shared.loadSettings()
        feedSources = settings.feedSources
        scheduleTime = settings.scheduleTime
        isScheduleEnabled = settings.isScheduleEnabled
        model = settings.model
        lastDigestDate = settings.lastDigestDate

        // Load default feeds if empty
        if feedSources.isEmpty {
            loadDefaultFeeds()
        }
    }

    func loadAPIKey() {
        #if DEBUG
        // Screenshot mode (see AppDelegate): never touch the Keychain, so no real key can appear.
        if UserDefaults.standard.string(forKey: "screenshotMode") != nil { return }
        #endif
        apiKey = StorageService.shared.loadAPIKey() ?? ""
    }

    func saveSettings() {
        // Save API key
        if !apiKey.isEmpty {
            _ = StorageService.shared.saveAPIKey(apiKey)
        }

        // Save app settings
        let settings = AppSettings(
            feedSources: feedSources,
            scheduleTime: scheduleTime,
            isScheduleEnabled: isScheduleEnabled,
            lastDigestDate: lastDigestDate,
            model: model
        )
        StorageService.shared.saveSettings(settings)
        SchedulerService.shared.apply(settings)
    }

    func testAPIKey() async {
        isTestingAPIKey = true
        apiKeyTestResult = nil

        do {
            guard StorageService.shared.saveAPIKey(apiKey) else {
                apiKeyTestResult = "✗ Could not save the key to the Keychain"
                isTestingAPIKey = false
                return
            }
            try await AnthropicService.shared.testConnection()
            apiKeyTestResult = "✓ API Key is valid"
        } catch {
            apiKeyTestResult = "✗ API Key test failed: \(error.localizedDescription)"
        }

        isTestingAPIKey = false
    }

    func addFeed(_ feed: FeedSource) {
        feedSources.append(feed)
        saveSettings()
    }

    func removeFeed(_ feed: FeedSource) {
        feedSources.removeAll { $0.id == feed.id }
        saveSettings()
    }

    func toggleFeed(_ feed: FeedSource) {
        if let index = feedSources.firstIndex(where: { $0.id == feed.id }) {
            feedSources[index].isEnabled.toggle()
            saveSettings()
        }
    }

    private func loadDefaultFeeds() {
        feedSources = StorageService.shared.loadDefaultFeeds()
        if !feedSources.isEmpty { saveSettings() }
    }
}
