import Foundation

/// Estimates how long a rendered HTML body takes to read. Latin tokens count
/// at 200 WPM; CJK characters (hiragana, katakana, ideographs) count at 450
/// CPM since CJK readers process individual characters rather than
/// whitespace-delimited words. Mixed-script bodies blend the two rates.
/// Result is rounded up to the nearest whole minute. Empty bodies return 0
/// so themes can suppress the label entirely.
public enum ReadingTime {
    public static let wordsPerMinute: Double = 200
    public static let cjkCharactersPerMinute: Double = 450

    public static func compute(html: String) -> Int {
        let stripped = strip(html)
        let (latin, cjk) = countLatinAndCJK(in: stripped)
        guard latin + cjk > 0 else { return 0 }
        let minutes = Double(latin) / wordsPerMinute + Double(cjk) / cjkCharactersPerMinute
        return Int(minutes.rounded(.up))
    }

    private static func strip(_ html: String) -> String {
        var stripped = html
        for tag in ["script", "style"] {
            let pattern = "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>"
            stripped = stripped.replacingOccurrences(
                of: pattern,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        stripped = stripped.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        stripped = stripped.replacingOccurrences(of: "&[a-zA-Z]+;", with: " ", options: .regularExpression)
        stripped = stripped.replacingOccurrences(of: "&#\\d+;", with: " ", options: .regularExpression)
        return stripped
    }

    /// Splits the stripped body into a CJK character count plus a count of
    /// whitespace-delimited Latin tokens. CJK characters are replaced with
    /// spaces in the Latin pass so they don't fuse adjacent Latin runs into
    /// a single token.
    private static func countLatinAndCJK(in stripped: String) -> (latin: Int, cjk: Int) {
        var cjkCount = 0
        var nonCJK = String.UnicodeScalarView()
        for scalar in stripped.unicodeScalars {
            if isCJK(scalar) {
                cjkCount += 1
                nonCJK.append(Unicode.Scalar(0x20)!)
            } else {
                nonCJK.append(scalar)
            }
        }
        let latinTokens = String(nonCJK).split(whereSeparator: { $0.isWhitespace }).count
        return (latinTokens, cjkCount)
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        // Hiragana, Katakana, CJK Unified Ideographs, CJK Extension A,
        // half-width katakana — covers Japanese, Chinese, Korean han.
        return (0x3040...0x309F).contains(value)
            || (0x30A0...0x30FF).contains(value)
            || (0x4E00...0x9FFF).contains(value)
            || (0x3400...0x4DBF).contains(value)
            || (0xFF66...0xFF9F).contains(value)
    }
}
