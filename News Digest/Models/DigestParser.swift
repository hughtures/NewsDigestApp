import Foundation

/// One story in a digest.
nonisolated struct DigestArticle: Equatable {
    var title: String
    var summary: String
    var sourceName: String?
    var url: URL?
}

nonisolated enum DigestElement: Equatable {
    case title(String)
    case section(String)
    case article(DigestArticle)
    case paragraph(String)
}

/// Turns the digest Markdown that Claude writes into structured elements.
///
/// The prompt asks for stories shaped like:
///
///     - **Headline**
///       Two or three sentences of summary.
///       🔗 *Source: Publication* - https://example.com/story
///
/// i.e. one bullet spread over several indented lines, which a line-by-line
/// renderer can't handle. This parser groups those lines into one article.
nonisolated enum DigestParser {
    static func parse(_ markdown: String) -> [DigestElement] {
        var elements: [DigestElement] = []
        var pending: [String] = []   // lines of the article currently being collected

        func flush() {
            guard !pending.isEmpty else { return }
            elements.append(.article(makeArticle(from: pending)))
            pending.removeAll()
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("## ") {
                flush(); elements.append(.section(String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                flush(); elements.append(.title(String(line.dropFirst(2))))
            } else if line.hasPrefix("- **") {
                flush(); pending = [line]
            } else if line.isEmpty {
                flush()
            } else if !pending.isEmpty {
                pending.append(line)               // continuation of the current article
            } else {
                elements.append(.paragraph(line))
            }
        }
        flush()
        return elements
    }

    private static func makeArticle(from lines: [String]) -> DigestArticle {
        let first = lines[0]
        var title = first
        var body = Array(lines.dropFirst())

        if let range = first.range(of: "\\*\\*(.+?)\\*\\*", options: .regularExpression) {
            title = String(first[range]).replacingOccurrences(of: "**", with: "")
            let rest = String(first[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !rest.isEmpty { body.insert(rest, at: 0) }
        }

        var summaryParts: [String] = []
        var sourceName: String?
        var url: URL?

        for line in body {
            // Everything before 🔗 is summary; everything after is the source citation.
            let pieces = line.components(separatedBy: "🔗")
            let text = pieces[0].trimmingCharacters(in: .whitespaces)
            if !text.isEmpty { summaryParts.append(text) }

            guard pieces.count > 1 else { continue }
            let citation = pieces[1]

            if let match = citation.range(of: "Source:\\s*(.+?)\\*?\\s+[-–—]\\s+https?://", options: .regularExpression) {
                sourceName = String(citation[match])
                    .replacingOccurrences(of: "Source:", with: "")
                    .replacingOccurrences(of: "*", with: "")
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: "http://", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: " -–—"))
            }
            if let urlRange = citation.range(of: "https?://[^\\s)\\]>]+", options: .regularExpression) {
                let raw = String(citation[urlRange]).trimmingCharacters(in: CharacterSet(charactersIn: ".,;"))
                url = URL(string: raw)
            }
        }

        return DigestArticle(
            title: title.trimmingCharacters(in: .whitespaces),
            summary: summaryParts.joined(separator: " "),
            sourceName: sourceName,
            url: url
        )
    }
}
