import os
import Foundation
import Security

class StorageService {
    static let shared = StorageService()

    private var userDefaults = UserDefaults.standard
    private let settingsKey = "app_settings"
    private let keychainService = "com.newsdigest.app"
    private let keychainAccount = "anthropic_api_key"

    private let digestsDirectory: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        digestsDirectory = appSupport.appendingPathComponent("NewsDigestApp/Digests", isDirectory: true)
    }

    /// For tests: keeps digests in a throwaway directory and settings in a
    /// private `UserDefaults` suite instead of touching the user's real data.
    init(digestsDirectory: URL, userDefaults: UserDefaults) {
        self.digestsDirectory = digestsDirectory
        self.userDefaults = userDefaults
    }

    // MARK: - Directories

    private func ensureDigestsDirectory() {
        try? FileManager.default.createDirectory(at: digestsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Settings

    func saveSettings(_ settings: AppSettings) {
        do {
            userDefaults.set(try JSONEncoder().encode(settings), forKey: settingsKey)
        } catch {
            Log.storage.error("Could not encode settings: \(error.localizedDescription, privacy: .public)")
        }
    }

    func loadSettings() -> AppSettings {
        guard let data = userDefaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    /// The feeds bundled with the app (`DefaultFeeds.json`).
    func loadDefaultFeeds() -> [FeedSource] {
        guard let url = Bundle.main.url(forResource: "DefaultFeeds", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let feeds = try? JSONDecoder().decode([FeedSource].self, from: data) else {
            Log.storage.error("DefaultFeeds.json missing or invalid")
            return []
        }
        return feeds
    }

    // MARK: - API Key (Keychain)

    func saveAPIKey(_ apiKey: String) -> Bool {
        let data = Data(apiKey.utf8)

        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        // Update in place if the item exists; otherwise add it. (Deleting first
        // would leave the user with no key if the add then failed.)
        let updateStatus = SecItemUpdate(identity as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        var newItem = identity
        newItem[kSecValueData as String] = data
        let status = SecItemAdd(newItem as CFDictionary, nil)
        if status != errSecSuccess {
            Log.storage.error("Keychain save failed: \(status)")
        }
        return status == errSecSuccess
    }

    func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }

        return apiKey
    }

    func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Digests

    func saveDigest(_ digest: NewsDigest) throws {
        ensureDigestsDirectory()
        let fileURL = digestsDirectory.appendingPathComponent(digest.fileName)
        try digest.content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func loadDigests() -> [NewsDigest] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: digestsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return files.compactMap { fileURL in
            guard fileURL.pathExtension == "md",
                  let content = try? String(contentsOf: fileURL, encoding: .utf8),
                  let date = NewsDigest.fileDateFormatter.date(from: fileURL.deletingPathExtension().lastPathComponent) else {
                return nil
            }

            return NewsDigest(date: date, content: content)
        }.sorted { $0.date > $1.date }
    }

    func deleteDigest(_ digest: NewsDigest) throws {
        let fileURL = digestsDirectory.appendingPathComponent(digest.fileName)
        try FileManager.default.removeItem(at: fileURL)
    }

    func getLatestDigest() -> NewsDigest? {
        return loadDigests().first
    }
}
