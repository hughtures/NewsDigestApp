import Foundation

nonisolated extension String {
    /// Converts an HTML fragment (as found in RSS `<description>` fields) to
    /// plain text.
    ///
    /// This deliberately avoids `NSAttributedString(html:)`, which spins up
    /// WebKit, is main-thread-only, and is far too heavy to run for hundreds of
    /// feed items on a background task.
    var strippingHTML: String {
        var text = self
        // Drop script/style blocks entirely, then every remaining tag.
        text = text.replacingOccurrences(of: "<(script|style)[^>]*>[\\s\\S]*?</\\1>", with: " ", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<br\\s*/?>|</p>", with: " ", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.decodingHTMLEntities
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var decodingHTMLEntities: String {
        let named: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&apos;": "'", "&#39;": "'", "&nbsp;": " ", "&mdash;": "—",
            "&ndash;": "–", "&hellip;": "…", "&rsquo;": "’", "&lsquo;": "‘",
            "&rdquo;": "”", "&ldquo;": "“"
        ]
        var result = self
        for (entity, value) in named where entity != "&amp;" {
            result = result.replacingOccurrences(of: entity, with: value)
        }

        // Numeric entities: &#8217; and &#x2019;
        let pattern = try? NSRegularExpression(pattern: "&#(x?)([0-9A-Fa-f]+);")
        let ns = result as NSString
        let matches = pattern?.matches(in: result, range: NSRange(location: 0, length: ns.length)) ?? []
        for match in matches.reversed() {
            let isHex = ns.substring(with: match.range(at: 1)) == "x"
            let digits = ns.substring(with: match.range(at: 2))
            if let code = UInt32(digits, radix: isHex ? 16 : 10), let scalar = Unicode.Scalar(code) {
                result = (result as NSString).replacingCharacters(in: match.range, with: String(Character(scalar)))
            }
        }

        // Decode &amp; last so "&amp;lt;" becomes "&lt;" and not "<".
        return result.replacingOccurrences(of: "&amp;", with: "&")
    }
}
