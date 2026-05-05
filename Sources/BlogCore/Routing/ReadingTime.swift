import Foundation

/// Estimates how long a rendered HTML body takes to read at 200 WPM, rounded
/// up to the nearest whole minute. Returns 0 for empty bodies — themes
/// suppress the label entirely in that case rather than display "0 min read".
public enum ReadingTime {
    public static let wordsPerMinute: Int = 200

    public static func compute(html: String) -> Int {
        let words = countWords(in: html)
        guard words > 0 else { return 0 }
        return Int((Double(words) / Double(wordsPerMinute)).rounded(.up))
    }

    private static func countWords(in html: String) -> Int {
        var stripped = html
        // Drop script and style payloads — their contents aren't reading
        // material even though they live inside the body markup.
        for tag in ["script", "style"] {
            let pattern = "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>"
            stripped = stripped.replacingOccurrences(
                of: pattern,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        // Strip remaining tags.
        stripped = stripped.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        // Strip common HTML entities so they don't inflate the word count.
        stripped = stripped.replacingOccurrences(of: "&[a-zA-Z]+;", with: " ", options: .regularExpression)
        stripped = stripped.replacingOccurrences(of: "&#\\d+;", with: " ", options: .regularExpression)
        let tokens = stripped.split(whereSeparator: { $0.isWhitespace })
        return tokens.count
    }
}
