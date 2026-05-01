import Foundation

public struct SocialLink: Codable, Equatable {
    public var label: String
    public var url: String

    public init(label: String, url: String) {
        self.label = label
        self.url = url
    }
}

public struct AuthorConfig: Codable, Equatable {
    public var name: String
    public var role: String?
    public var location: String?
    public var email: String?
    public var social: [SocialLink]?
    /// Short one-liner shown beside the brand mark (e.g. "iOS · Growth · Tokyo").
    public var tagline: String?
    /// Optional timezone label rendered in the footer (e.g. "GMT+9").
    public var timezone: String?
    /// Optional tagline shown in the homepage hero summary (overrides
    /// site.description when present).
    public var heroSummary: String?
    /// Optional one-line quote shown in the homepage about teaser.
    public var aboutTeaser: String?
    /// Optional path/URL for the portrait shown in the about teaser and the
    /// /about/ page. Use `/assets/...` to resolve from `static/assets/`.
    public var portrait: String?

    public init(
        name: String,
        role: String? = nil,
        location: String? = nil,
        email: String? = nil,
        social: [SocialLink]? = nil,
        tagline: String? = nil,
        timezone: String? = nil,
        heroSummary: String? = nil,
        aboutTeaser: String? = nil,
        portrait: String? = nil
    ) {
        self.name = name
        self.role = role
        self.location = location
        self.email = email
        self.social = social
        self.tagline = tagline
        self.timezone = timezone
        self.heroSummary = heroSummary
        self.aboutTeaser = aboutTeaser
        self.portrait = portrait
    }
}
