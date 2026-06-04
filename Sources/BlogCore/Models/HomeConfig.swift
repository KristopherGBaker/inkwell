import Foundation

public struct HomeConfig: Codable, Equatable {
    public var template: String
    public var featuredCollection: String?
    public var featuredCount: Int?
    public var recentCollection: String?
    public var recentCount: Int?
    /// Optional third home section ("What I'm building"): a collection — usually
    /// a child/updates collection — whose most recent items render between the
    /// featured and recent sections. Hidden when unset.
    public var buildingCollection: String?
    public var buildingCount: Int?
    public var heroPrimaryCta: HomeCta?
    public var heroSecondaryCta: HomeCta?
    public var featuredLabel: String?
    public var featuredCta: HomeCta?
    public var recentLabel: String?
    public var recentCta: HomeCta?
    public var buildingLabel: String?
    public var buildingCta: HomeCta?
    public var aboutEyebrow: String?
    public var aboutLinks: [HomeCta]?

    public init(
        template: String,
        featuredCollection: String? = nil,
        featuredCount: Int? = nil,
        recentCollection: String? = nil,
        recentCount: Int? = nil,
        buildingCollection: String? = nil,
        buildingCount: Int? = nil,
        heroPrimaryCta: HomeCta? = nil,
        heroSecondaryCta: HomeCta? = nil,
        featuredLabel: String? = nil,
        featuredCta: HomeCta? = nil,
        recentLabel: String? = nil,
        recentCta: HomeCta? = nil,
        buildingLabel: String? = nil,
        buildingCta: HomeCta? = nil,
        aboutEyebrow: String? = nil,
        aboutLinks: [HomeCta]? = nil
    ) {
        self.template = template
        self.featuredCollection = featuredCollection
        self.featuredCount = featuredCount
        self.recentCollection = recentCollection
        self.recentCount = recentCount
        self.buildingCollection = buildingCollection
        self.buildingCount = buildingCount
        self.heroPrimaryCta = heroPrimaryCta
        self.heroSecondaryCta = heroSecondaryCta
        self.featuredLabel = featuredLabel
        self.featuredCta = featuredCta
        self.recentLabel = recentLabel
        self.recentCta = recentCta
        self.buildingLabel = buildingLabel
        self.buildingCta = buildingCta
        self.aboutEyebrow = aboutEyebrow
        self.aboutLinks = aboutLinks
    }
}
