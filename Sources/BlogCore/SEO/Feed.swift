import Foundation

/// A format-agnostic feed model. `SEOArtifactsWriter` builds one `FeedChannel`
/// per language, then renders it as RSS 2.0, Atom 1.0, and JSON Feed so the
/// three formats can never drift apart.
struct FeedChannel {
    let title: String
    /// Absolute, language-prefixed site home URL.
    let homeLink: String
    let summary: String
    /// BCP-47 language tag, or nil for a monolingual feed.
    let language: String?
    let authorName: String?
    let authorEmail: String?
    let selfRSSURL: String
    let selfAtomURL: String
    let selfJSONURL: String
    /// Newest item date; drives `<lastBuildDate>` / Atom `<updated>`.
    let updated: Date?
    let items: [FeedItem]
}

struct FeedItem {
    let title: String
    /// Absolute permalink, used as both link and stable id.
    let link: String
    let date: Date?
    /// Plain summary text (already trimmed, not yet escaped).
    let summary: String
    /// Full rendered HTML body with absolutized URLs, or nil when unavailable.
    let contentHTML: String?
    let categories: [String]
}

// MARK: - Date formatting

/// Parses front-matter ISO dates and re-emits them in the formats each feed
/// standard requires: RFC-822 for RSS, RFC-3339 for Atom and JSON Feed.
enum FeedDate {
    private static func isoFormatter(fractional: Bool) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = fractional
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        return formatter
    }

    private static func gmtFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = format
        return formatter
    }

    /// Leniently parses an ISO date string (with time, with fractional
    /// seconds, or date-only). Returns nil when nothing matches.
    static func parse(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), raw.isEmpty == false else {
            return nil
        }
        if let date = isoFormatter(fractional: false).date(from: raw) { return date }
        if let date = isoFormatter(fractional: true).date(from: raw) { return date }
        if let date = gmtFormatter("yyyy-MM-dd").date(from: raw) { return date }
        return nil
    }

    static func rfc822(_ date: Date) -> String {
        gmtFormatter("EEE, dd MMM yyyy HH:mm:ss Z").string(from: date)
    }

    static func rfc3339(_ date: Date) -> String {
        isoFormatter(fractional: false).string(from: date)
    }
}

// MARK: - URL absolutization

/// Rewrites root-relative URLs (`src`/`href`/`poster`/`srcset` values starting
/// with `/`) to absolute URLs so feed readers, which have no document base,
/// can resolve images and links. Rendered bodies use root-relative asset URLs
/// without the deploy base path, so prefixing the full `baseURL` is correct.
func absolutizeFeedURLs(in html: String, baseURL: String) -> String {
    guard html.isEmpty == false else { return html }
    let origin = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL

    var result = html
    // src/href/poster="/..." -> src/href/poster="<origin>/..."
    result = result.replacingOccurrences(
        of: #"(\s(?:src|href|poster)=")/"#,
        with: "$1\(origin)/",
        options: .regularExpression
    )
    // srcset entries: each candidate URL begins after a comma or the quote.
    result = result.replacingOccurrences(
        of: #"(\ssrcset=")/"#,
        with: "$1\(origin)/",
        options: .regularExpression
    )
    result = result.replacingOccurrences(
        of: #"(,\s*)/"#,
        with: "$1\(origin)/",
        options: .regularExpression
    )
    return result
}

// MARK: - RSS 2.0

func renderRSS(_ channel: FeedChannel) -> String {
    let generator = "Inkwell \(InkwellVersion.current)"
    var channelLines: [String] = [
        "    <title>\(xmlEscape(channel.title))</title>",
        "    <link>\(xmlEscape(channel.homeLink))</link>",
        "    <atom:link href=\"\(xmlEscape(channel.selfRSSURL))\" rel=\"self\" type=\"application/rss+xml\"/>",
        "    <description>\(xmlEscape(channel.summary))</description>",
        "    <generator>\(xmlEscape(generator))</generator>"
    ]
    if let language = channel.language {
        channelLines.append("    <language>\(xmlEscape(language))</language>")
    }
    if let updated = channel.updated {
        channelLines.append("    <lastBuildDate>\(xmlEscape(FeedDate.rfc822(updated)))</lastBuildDate>")
    }
    if let authorName = channel.authorName {
        let managing = channel.authorEmail.map { "\($0) (\(authorName))" } ?? authorName
        channelLines.append("    <managingEditor>\(xmlEscape(managing))</managingEditor>")
    }

    let items = channel.items.map { item -> String in
        var lines: [String] = [
            "    <item>",
            "      <title>\(xmlEscape(item.title))</title>",
            "      <link>\(xmlEscape(item.link))</link>",
            "      <guid isPermaLink=\"true\">\(xmlEscape(item.link))</guid>"
        ]
        if let date = item.date {
            lines.append("      <pubDate>\(xmlEscape(FeedDate.rfc822(date)))</pubDate>")
        }
        for category in item.categories {
            lines.append("      <category>\(xmlEscape(category))</category>")
        }
        if item.summary.isEmpty == false {
            lines.append("      <description>\(xmlEscape(item.summary))</description>")
        }
        if let content = item.contentHTML, content.isEmpty == false {
            lines.append("      <content:encoded><![CDATA[\(cdataSafe(content))]]></content:encoded>")
        }
        lines.append("    </item>")
        return lines.joined(separator: "\n")
    }.joined(separator: "\n")

    return """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" \
    xmlns:content="http://purl.org/rss/1.0/modules/content/">
      <channel>
    \(channelLines.joined(separator: "\n"))
    \(items)
      </channel>
    </rss>
    """
}

// MARK: - Atom 1.0

func renderAtom(_ channel: FeedChannel) -> String {
    let generator = "Inkwell"
    let updated = channel.updated ?? channel.items.first?.date
    var feedLines: [String] = [
        "  <title>\(xmlEscape(channel.title))</title>",
        "  <subtitle>\(xmlEscape(channel.summary))</subtitle>",
        "  <link href=\"\(xmlEscape(channel.homeLink))\" rel=\"alternate\"/>",
        "  <link href=\"\(xmlEscape(channel.selfAtomURL))\" rel=\"self\" type=\"application/atom+xml\"/>",
        "  <id>\(xmlEscape(channel.homeLink))</id>",
        "  <generator version=\"\(xmlEscape(InkwellVersion.current))\">\(xmlEscape(generator))</generator>"
    ]
    if let updated = updated {
        feedLines.append("  <updated>\(xmlEscape(FeedDate.rfc3339(updated)))</updated>")
    }
    if let authorName = channel.authorName {
        var author = ["  <author>", "    <name>\(xmlEscape(authorName))</name>"]
        if let email = channel.authorEmail {
            author.append("    <email>\(xmlEscape(email))</email>")
        }
        author.append("  </author>")
        feedLines.append(contentsOf: author)
    }

    let entries = channel.items.map { item -> String in
        var lines: [String] = [
            "  <entry>",
            "    <title>\(xmlEscape(item.title))</title>",
            "    <link href=\"\(xmlEscape(item.link))\" rel=\"alternate\"/>",
            "    <id>\(xmlEscape(item.link))</id>"
        ]
        if let date = item.date {
            lines.append("    <updated>\(xmlEscape(FeedDate.rfc3339(date)))</updated>")
            lines.append("    <published>\(xmlEscape(FeedDate.rfc3339(date)))</published>")
        }
        for category in item.categories {
            lines.append("    <category term=\"\(xmlEscape(category))\"/>")
        }
        if item.summary.isEmpty == false {
            lines.append("    <summary>\(xmlEscape(item.summary))</summary>")
        }
        if let content = item.contentHTML, content.isEmpty == false {
            lines.append("    <content type=\"html\"><![CDATA[\(cdataSafe(content))]]></content>")
        }
        lines.append("  </entry>")
        return lines.joined(separator: "\n")
    }.joined(separator: "\n")

    let langAttr = channel.language.map { " xml:lang=\"\(xmlEscape($0))\"" } ?? ""
    return """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom"\(langAttr)>
    \(feedLines.joined(separator: "\n"))
    \(entries)
    </feed>
    """
}

// MARK: - JSON Feed 1.1

func renderJSONFeed(_ channel: FeedChannel) -> String {
    let author = channel.authorName.map { JSONFeedAuthor(name: $0) }
    let items = channel.items.map { item -> JSONFeedItem in
        JSONFeedItem(
            id: item.link,
            url: item.link,
            title: item.title,
            contentHTML: item.contentHTML,
            contentText: item.contentHTML == nil ? item.summary : nil,
            summary: item.summary.isEmpty ? nil : item.summary,
            datePublished: item.date.map(FeedDate.rfc3339),
            tags: item.categories.isEmpty ? nil : item.categories
        )
    }
    let feed = JSONFeed(
        version: "https://jsonfeed.org/version/1.1",
        title: channel.title,
        homePageURL: channel.homeLink,
        feedURL: channel.selfJSONURL,
        description: channel.summary.isEmpty ? nil : channel.summary,
        language: channel.language,
        authors: author.map { [$0] },
        items: items
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
    encoder.keyEncodingStrategy = .useDefaultKeys
    guard let data = try? encoder.encode(feed), let json = String(data: data, encoding: .utf8) else {
        return "{}"
    }
    return json
}

private struct JSONFeed: Encodable {
    let version: String
    let title: String
    let homePageURL: String
    let feedURL: String
    let description: String?
    let language: String?
    let authors: [JSONFeedAuthor]?
    let items: [JSONFeedItem]

    enum CodingKeys: String, CodingKey {
        case version, title, description, language, authors, items
        case homePageURL = "home_page_url"
        case feedURL = "feed_url"
    }
}

private struct JSONFeedAuthor: Encodable {
    let name: String
}

private struct JSONFeedItem: Encodable {
    let id: String
    let url: String
    let title: String
    let contentHTML: String?
    let contentText: String?
    let summary: String?
    let datePublished: String?
    let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case id, url, title, summary, tags
        case contentHTML = "content_html"
        case contentText = "content_text"
        case datePublished = "date_published"
    }
}

/// Escapes a `]]>` sequence so embedded HTML can't terminate the CDATA block.
private func cdataSafe(_ value: String) -> String {
    value.replacingOccurrences(of: "]]>", with: "]]]]><![CDATA[>")
}
