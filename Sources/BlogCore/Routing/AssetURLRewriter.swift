import Foundation

/// Rewrites relative `src` / `href` / `poster` URLs in a snippet of HTML to
/// absolute URLs rooted at `base`. Useful when the same rendered HTML is
/// served from multiple URLs (e.g., a post mounted at `/posts/foo/` and at
/// `/<lang>/posts/foo/`) but its co-located assets only live at the
/// canonical path.
///
/// Skips already-absolute URLs (starting with `/`, `#`, `?`, `mailto:`,
/// `tel:`, `data:`, or any `scheme://`). Leaves `srcset` alone — its
/// comma-separated list with descriptors needs special handling that v1
/// doesn't ship.
public enum AssetURLRewriter {
    public static func rewriteRelativeURLs(in html: String, base: String) -> String {
        let pattern = #"(\s(?:src|href|poster)=")([^"]+)(")"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return html
        }
        let nsHTML = html as NSString
        let fullRange = NSRange(location: 0, length: nsHTML.length)

        var result = ""
        var cursor = 0
        regex.enumerateMatches(in: html, options: [], range: fullRange) { match, _, _ in
            guard let match else { return }
            let attrRange = match.range(at: 1)
            let valueRange = match.range(at: 2)
            let closeRange = match.range(at: 3)

            let preceding = NSRange(location: cursor, length: match.range.location - cursor)
            result += nsHTML.substring(with: preceding)
            result += nsHTML.substring(with: attrRange)
            let original = nsHTML.substring(with: valueRange)
            result += resolved(original, base: base)
            result += nsHTML.substring(with: closeRange)
            cursor = match.range.location + match.range.length
        }
        if cursor < nsHTML.length {
            result += nsHTML.substring(from: cursor)
        }
        return result
    }

    private static func resolved(_ value: String, base: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return value }
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("#") || trimmed.hasPrefix("?") {
            return value
        }
        if trimmed.contains("://") {
            return value
        }
        if trimmed.hasPrefix("mailto:") || trimmed.hasPrefix("tel:") || trimmed.hasPrefix("data:") {
            return value
        }
        let normalized = base.hasSuffix("/") ? base : base + "/"
        return normalized + value
    }
}
