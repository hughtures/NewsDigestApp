import Foundation

struct AppSettings: Codable, Equatable {
    var feedSources: [FeedSource]
    var scheduleTime: DateComponents
    var isScheduleEnabled: Bool
    var lastDigestDate: Date?
    /// Claude model ID used to write the digest. Stored as a raw string so a
    /// model chosen in a newer build still round-trips.
    var model: String

    init(
        feedSources: [FeedSource] = [],
        scheduleTime: DateComponents = DateComponents(hour: 6, minute: 0),
        isScheduleEnabled: Bool = true,
        lastDigestDate: Date? = nil,
        model: String = ClaudeModel.default.rawValue
    ) {
        self.feedSources = feedSources
        self.scheduleTime = scheduleTime
        self.isScheduleEnabled = isScheduleEnabled
        self.lastDigestDate = lastDigestDate
        self.model = model
    }

    // Custom decoding so settings saved by older versions (which had no
    // `model` key) still load instead of silently resetting the user's feeds.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        feedSources = try c.decodeIfPresent([FeedSource].self, forKey: .feedSources) ?? []
        scheduleTime = try c.decodeIfPresent(DateComponents.self, forKey: .scheduleTime)
            ?? DateComponents(hour: 6, minute: 0)
        isScheduleEnabled = try c.decodeIfPresent(Bool.self, forKey: .isScheduleEnabled) ?? true
        lastDigestDate = try c.decodeIfPresent(Date.self, forKey: .lastDigestDate)
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ClaudeModel.default.rawValue
    }

    static let `default` = AppSettings()
}
