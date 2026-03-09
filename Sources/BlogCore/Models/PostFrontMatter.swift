import Foundation

public struct PostFrontMatter: Codable, Equatable {
    public var title: String?
    public var date: String?
    public var slug: String?
    public var summary: String?
    public var tags: [String]?
    public var categories: [String]?
    public var draft: Bool?
    public var series: String?
    public var canonicalUrl: String?
    public var coverImage: String?

    public init(
        title: String?,
        date: String?,
        slug: String?,
        summary: String? = nil,
        tags: [String]? = nil,
        categories: [String]? = nil,
        draft: Bool? = nil,
        series: String? = nil,
        canonicalUrl: String? = nil,
        coverImage: String? = nil
    ) {
        self.title = title
        self.date = date
        self.slug = slug
        self.summary = summary
        self.tags = tags
        self.categories = categories
        self.draft = draft
        self.series = series
        self.canonicalUrl = canonicalUrl
        self.coverImage = coverImage
    }

    public var normalizedCanonicalURL: String? {
        guard let canonicalUrl else { return nil }
        let trimmed = canonicalUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
