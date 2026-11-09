import Testing
import Foundation
@testable import News_Digest

@MainActor
struct StorageServiceTests {
    func makeStorage() -> (StorageService, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("NewsDigestTests-\(UUID().uuidString)")
        let defaults = UserDefaults(suiteName: "NewsDigestTests-\(UUID().uuidString)")!
        return (StorageService(digestsDirectory: dir, userDefaults: defaults), dir)
    }

    func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: .current, year: y, month: m, day: d, hour: 12).date!
    }

    @Test func savesAndLoadsDigestsNewestFirst() throws {
        let (storage, dir) = makeStorage()
        defer { try? FileManager.default.removeItem(at: dir) }

        try storage.saveDigest(NewsDigest(date: day(2026, 11, 7), content: "- **Old**"))
        try storage.saveDigest(NewsDigest(date: day(2026, 11, 9), content: "- **A**\n- **B**"))

        let loaded = storage.loadDigests()
        #expect(loaded.map(\.articleCount) == [2, 1])
        #expect(storage.getLatestDigest()?.content == "- **A**\n- **B**")
    }

    @Test func deleteRemovesDigest() throws {
        let (storage, dir) = makeStorage()
        defer { try? FileManager.default.removeItem(at: dir) }

        let digest = NewsDigest(date: day(2026, 11, 9), content: "- **A**")
        try storage.saveDigest(digest)
        try storage.deleteDigest(digest)
        #expect(storage.loadDigests().isEmpty)
    }

    @Test func ignoresStrayFilesInDigestFolder() throws {
        let (storage, dir) = makeStorage()
        defer { try? FileManager.default.removeItem(at: dir) }

        try storage.saveDigest(NewsDigest(date: day(2026, 11, 9), content: "- **A**"))
        try "junk".write(to: dir.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
        try "junk".write(to: dir.appendingPathComponent("not-a-date.md"), atomically: true, encoding: .utf8)
        #expect(storage.loadDigests().count == 1)
    }

    @Test func emptyStorageReturnsNothing() {
        let (storage, _) = makeStorage()
        #expect(storage.loadDigests().isEmpty)
        #expect(storage.getLatestDigest() == nil)
    }

    @Test func settingsPersistAndDefaultWhenAbsent() {
        let (storage, _) = makeStorage()
        #expect(storage.loadSettings() == .default)

        var settings = AppSettings(feedSources: [Fixture.feed], model: ClaudeModel.haiku.rawValue)
        settings.isScheduleEnabled = false
        storage.saveSettings(settings)
        #expect(storage.loadSettings() == settings)
    }
}
