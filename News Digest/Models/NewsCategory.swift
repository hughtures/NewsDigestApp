import Foundation

nonisolated enum NewsCategory: String, Codable, CaseIterable, Identifiable {
    case topNews = "top_news"
    case ai = "ai"
    case usPolitics = "us_politics"
    case filmTV = "film_tv"
    case tech = "tech"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topNews: return "Top Stories"
        case .ai: return "Artificial Intelligence"
        case .usPolitics: return "US Politics"
        case .filmTV: return "Film & Television"
        case .tech: return "Technology"
        }
    }

    var emoji: String {
        switch self {
        case .topNews: return "🔴"
        case .ai: return "🤖"
        case .usPolitics: return "🇺🇸"
        case .filmTV: return "🎬"
        case .tech: return "💻"
        }
    }

    var sectionTitle: String {
        "\(emoji) \(displayName)"
    }
}
