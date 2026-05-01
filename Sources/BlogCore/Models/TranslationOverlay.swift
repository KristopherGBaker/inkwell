import Foundation

/// Per-language overlay for the localizable surface of `SiteConfig`. Any field
/// set here replaces the default-language equivalent when rendering pages in
/// that language; unset fields fall back to the default-language config.
///
/// Stored on `SiteConfig.translations` keyed by BCP-47 language tag (e.g.
/// `"ja"`).
public struct TranslationOverlay: Codable, Equatable {
    public var title: String?
    public var description: String?
    public var tagline: String?
    public var heroHeadline: String?
    public var footerCta: FooterCtaConfig?
    public var themeCopy: ThemeCopyConfig?
    public var nav: [NavItem]?
    public var home: HomeOverlay?
    public var collections: [CollectionOverlay]?
    public var author: AuthorOverlay?

    public init(
        title: String? = nil,
        description: String? = nil,
        tagline: String? = nil,
        heroHeadline: String? = nil,
        footerCta: FooterCtaConfig? = nil,
        themeCopy: ThemeCopyConfig? = nil,
        nav: [NavItem]? = nil,
        home: HomeOverlay? = nil,
        collections: [CollectionOverlay]? = nil,
        author: AuthorOverlay? = nil
    ) {
        self.title = title
        self.description = description
        self.tagline = tagline
        self.heroHeadline = heroHeadline
        self.footerCta = footerCta
        self.themeCopy = themeCopy
        self.nav = nav
        self.home = home
        self.collections = collections
        self.author = author
    }
}

/// Translatable subset of `HomeConfig`. `template`, `featuredCollection`,
/// `recentCollection`, etc. are structural and not localized.
public struct HomeOverlay: Codable, Equatable {
    public var heroPrimaryCta: HomeCta?
    public var heroSecondaryCta: HomeCta?
    public var featuredLabel: String?
    public var featuredCta: HomeCta?
    public var recentLabel: String?
    public var recentCta: HomeCta?
    public var aboutEyebrow: String?
    public var aboutLinks: [HomeCta]?

    public init(
        heroPrimaryCta: HomeCta? = nil,
        heroSecondaryCta: HomeCta? = nil,
        featuredLabel: String? = nil,
        featuredCta: HomeCta? = nil,
        recentLabel: String? = nil,
        recentCta: HomeCta? = nil,
        aboutEyebrow: String? = nil,
        aboutLinks: [HomeCta]? = nil
    ) {
        self.heroPrimaryCta = heroPrimaryCta
        self.heroSecondaryCta = heroSecondaryCta
        self.featuredLabel = featuredLabel
        self.featuredCta = featuredCta
        self.recentLabel = recentLabel
        self.recentCta = recentCta
        self.aboutEyebrow = aboutEyebrow
        self.aboutLinks = aboutLinks
    }
}

/// Translatable subset of `CollectionConfig`, keyed by `id`. Routes, sort
/// keys, and template paths are structural and not localized.
public struct CollectionOverlay: Codable, Equatable {
    public var id: String
    public var eyebrow: String?
    public var headline: String?
    public var lede: String?

    public init(id: String, eyebrow: String? = nil, headline: String? = nil, lede: String? = nil) {
        self.id = id
        self.eyebrow = eyebrow
        self.headline = headline
        self.lede = lede
    }
}

/// Translatable subset of `AuthorConfig`. `name`, `email`, `social[].url`, and
/// `portrait` are not localized; everything else is opt-in.
public struct AuthorOverlay: Codable, Equatable {
    public var role: String?
    public var location: String?
    public var tagline: String?
    public var timezone: String?
    public var heroSummary: String?
    public var aboutTeaser: String?

    public init(
        role: String? = nil,
        location: String? = nil,
        tagline: String? = nil,
        timezone: String? = nil,
        heroSummary: String? = nil,
        aboutTeaser: String? = nil
    ) {
        self.role = role
        self.location = location
        self.tagline = tagline
        self.timezone = timezone
        self.heroSummary = heroSummary
        self.aboutTeaser = aboutTeaser
    }
}
