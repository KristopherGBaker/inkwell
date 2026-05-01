import Foundation

public struct SiteConfig: Codable, Equatable {
    public var title: String
    public var baseURL: String
    public var theme: String
    public var outputDir: String
    public var description: String?
    public var tagline: String?
    public var searchEnabled: Bool?
    /// Path (relative to the project root) to an HTML fragment whose contents
    /// are injected into every page's `<head>`. Useful for favicons, analytics
    /// snippets, structured data, or other per-site metadata.
    public var head: String?
    public var author: AuthorConfig?
    public var nav: [NavItem]?
    public var collections: [CollectionConfig]?
    public var home: HomeConfig?
    /// Optional homepage hero headline. Use `*word*` to mark italic-accent
    /// segments (rendered with the theme's accent color). Falls back to the
    /// site title when not set.
    public var heroHeadline: String?
    /// Optional footer call-to-action overrides. When unset, the theme's
    /// default eyebrow/headline copy is used.
    public var footerCta: FooterCtaConfig?
    /// Optional theme-level chrome strings (work-card CTA, case-study
    /// next/back, about-page CTAs, 404 copy, theme-toggle aria). Each field
    /// falls back to the theme's English default when unset.
    public var themeCopy: ThemeCopyConfig?
    /// Optional multi-language settings. When unset, the site is monolingual.
    public var i18n: I18nConfig?
    /// Optional per-language overlay map keyed by BCP-47 tag (e.g. `"ja"`).
    /// Each value supplies translated overrides for the localizable surface
    /// of `SiteConfig`; unset fields fall back to the default-language values.
    public var translations: [String: TranslationOverlay]?

    public init(
        title: String,
        baseURL: String = "/",
        theme: String = "default",
        outputDir: String = "docs",
        description: String? = nil,
        tagline: String? = nil,
        searchEnabled: Bool? = nil,
        head: String? = nil,
        author: AuthorConfig? = nil,
        nav: [NavItem]? = nil,
        collections: [CollectionConfig]? = nil,
        home: HomeConfig? = nil,
        heroHeadline: String? = nil,
        footerCta: FooterCtaConfig? = nil,
        themeCopy: ThemeCopyConfig? = nil,
        i18n: I18nConfig? = nil,
        translations: [String: TranslationOverlay]? = nil
    ) {
        self.title = title
        self.baseURL = baseURL
        self.theme = theme
        self.outputDir = outputDir
        self.description = description
        self.tagline = tagline
        self.searchEnabled = searchEnabled
        self.head = head
        self.author = author
        self.nav = nav
        self.collections = collections
        self.home = home
        self.heroHeadline = heroHeadline
        self.footerCta = footerCta
        self.themeCopy = themeCopy
        self.i18n = i18n
        self.translations = translations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Blog"
        self.baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? "/"
        self.theme = try container.decodeIfPresent(String.self, forKey: .theme) ?? "default"
        self.outputDir = try container.decodeIfPresent(String.self, forKey: .outputDir) ?? "docs"
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.tagline = try container.decodeIfPresent(String.self, forKey: .tagline)
        self.searchEnabled = try container.decodeIfPresent(Bool.self, forKey: .searchEnabled)
        self.head = try container.decodeIfPresent(String.self, forKey: .head)
        self.author = try container.decodeIfPresent(AuthorConfig.self, forKey: .author)
        self.nav = try container.decodeIfPresent([NavItem].self, forKey: .nav)
        self.collections = try container.decodeIfPresent([CollectionConfig].self, forKey: .collections)
        self.home = try container.decodeIfPresent(HomeConfig.self, forKey: .home)
        self.heroHeadline = try container.decodeIfPresent(String.self, forKey: .heroHeadline)
        self.footerCta = try container.decodeIfPresent(FooterCtaConfig.self, forKey: .footerCta)
        self.themeCopy = try container.decodeIfPresent(ThemeCopyConfig.self, forKey: .themeCopy)
        self.i18n = try container.decodeIfPresent(I18nConfig.self, forKey: .i18n)
        self.translations = try container.decodeIfPresent([String: TranslationOverlay].self, forKey: .translations)
    }
}
