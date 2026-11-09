import Foundation

/// Claude models the user can pick in Settings.
enum ClaudeModel: String, CaseIterable, Identifiable {
    case haiku = "claude-haiku-5-5"
    case sonnet = "claude-sonnet-5-5"
    case opus = "claude-opus-5-5"

    static let `default`: ClaudeModel = .sonnet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .haiku: return "Haiku 5.5 – fastest, lowest cost"
        case .sonnet: return "Sonnet 5.5 – balanced (default)"
        case .opus: return "Opus 5.5 – most capable"
        }
    }
}
