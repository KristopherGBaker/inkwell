import Foundation

/// Extracts a flat list of `<h2>` and `<h3>` headings from rendered HTML and
/// rewrites the HTML so each heading carries an `id` attribute. The `id` is
/// either the heading's existing `id` or a slug derived from the heading
/// text. Duplicate slugs are deduplicated by appending `-2`, `-3`, etc.
///
/// Used by `PageContextBuilder` to populate `page.toc` for long-form posts
/// and case studies; the rewritten HTML lets anchor links work even when the
/// theme isn't rendering a TOC.
public enum HeadingExtractor {
    public struct Heading: Equatable {
        public let level: Int
        public let text: String
        public let anchor: String
    }

    public struct Result: Equatable {
        public let html: String
        public let headings: [Heading]
    }

    public static func extract(html: String) -> Result {
        let pattern = "<h([23])([^>]*)>([\\s\\S]*?)</h\\1>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return Result(html: html, headings: [])
        }

        let nsHTML = html as NSString
        var rewritten = ""
        var cursor = 0
        var headings: [Heading] = []
        var seenAnchors: [String: Int] = [:]

        regex.enumerateMatches(in: html, range: NSRange(location: 0, length: nsHTML.length)) { match, _, _ in
            guard let match else { return }
            rewritten += nsHTML.substring(with: NSRange(location: cursor, length: match.range.location - cursor))

            let level = Int(nsHTML.substring(with: match.range(at: 1))) ?? 2
            let attrs = nsHTML.substring(with: match.range(at: 2))
            let inner = nsHTML.substring(with: match.range(at: 3))

            let visibleText = stripTags(inner).trimmingCharacters(in: .whitespacesAndNewlines)
            let preferredAnchor = existingID(in: attrs) ?? slugify(visibleText)
            let uniqueAnchor = uniquify(preferredAnchor, in: &seenAnchors)

            let newAttrs = setOrReplaceID(attrs, anchor: uniqueAnchor)
            rewritten += "<h\(level)\(newAttrs)>\(inner)</h\(level)>"

            headings.append(Heading(level: level, text: visibleText, anchor: uniqueAnchor))
            cursor = match.range.location + match.range.length
        }
        if cursor < nsHTML.length {
            rewritten += nsHTML.substring(from: cursor)
        }

        return Result(html: rewritten, headings: headings)
    }

    private static func existingID(in attrs: String) -> String? {
        let pattern = "\\bid\\s*=\\s*\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: attrs, range: NSRange(location: 0, length: (attrs as NSString).length)) else {
            return nil
        }
        let value = (attrs as NSString).substring(with: match.range(at: 1))
        return value.isEmpty ? nil : value
    }

    private static func setOrReplaceID(_ attrs: String, anchor: String) -> String {
        let pattern = "\\bid\\s*=\\s*\"[^\"]*\""
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           regex.firstMatch(in: attrs, range: NSRange(location: 0, length: (attrs as NSString).length)) != nil {
            return regex.stringByReplacingMatches(
                in: attrs,
                range: NSRange(location: 0, length: (attrs as NSString).length),
                withTemplate: "id=\"\(anchor)\""
            )
        }
        return " id=\"\(anchor)\"" + attrs
    }

    private static func stripTags(_ inner: String) -> String {
        let withoutTags = inner.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return withoutTags.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func slugify(_ text: String) -> String {
        let lowered = text.lowercased()
        var stripped = lowered.replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        stripped = stripped.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return stripped.isEmpty ? "section" : stripped
    }

    private static func uniquify(_ slug: String, in seen: inout [String: Int]) -> String {
        let count = seen[slug, default: 0] + 1
        seen[slug] = count
        return count == 1 ? slug : "\(slug)-\(count)"
    }
}
