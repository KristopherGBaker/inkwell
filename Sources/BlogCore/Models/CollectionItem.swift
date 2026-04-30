import Foundation

/// A single piece of content loaded from a collection. Carries the typed
/// fields blog posts have always exposed (title, slug, date, etc.) plus
/// the raw front-matter dictionary so collection-specific fields like
/// `year`, `metrics`, or `shots` stay accessible to templates.
public struct CollectionItem {
    public var slug: String
    public var title: String
    public var date: String?
    public var summary: String?
    public var tags: [String]?
    public var categories: [String]?
    public var draft: Bool?
    public var series: String?
    public var canonicalUrl: String?
    public var coverImage: String?
    /// Raw decoded front-matter dictionary, including all typed fields plus
    /// any untyped extras supplied by the author.
    public var frontMatter: [String: Any]
    public var body: String
    public var sourcePath: URL

    public init(
        slug: String,
        title: String,
        date: String? = nil,
        summary: String? = nil,
        tags: [String]? = nil,
        categories: [String]? = nil,
        draft: Bool? = nil,
        series: String? = nil,
        canonicalUrl: String? = nil,
        coverImage: String? = nil,
        frontMatter: [String: Any] = [:],
        body: String = "",
        sourcePath: URL = URL(fileURLWithPath: "/dev/null")
    ) {
        self.slug = slug
        self.title = title
        self.date = date
        self.summary = summary
        self.tags = tags
        self.categories = categories
        self.draft = draft
        self.series = series
        self.canonicalUrl = canonicalUrl
        self.coverImage = coverImage
        self.frontMatter = frontMatter
        self.body = body
        self.sourcePath = sourcePath
    }

    public var normalizedCanonicalURL: String? {
        guard let url = canonicalUrl?.trimmingCharacters(in: .whitespacesAndNewlines), url.isEmpty == false else {
            return nil
        }
        return url
    }
}

public struct Collection {
    public var config: CollectionConfig
    public var items: [CollectionItem]

    public init(config: CollectionConfig, items: [CollectionItem]) {
        self.config = config
        self.items = items
    }
}
