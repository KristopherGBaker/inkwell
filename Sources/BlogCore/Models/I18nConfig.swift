import Foundation

/// Multi-language settings for a site. When omitted entirely, sites are
/// monolingual and behave exactly as before. When present, the renderer
/// emits one set of plans per language: the default language at canonical
/// root URLs, others prefixed (`/<lang>/...`).
public struct I18nConfig: Codable, Equatable {
    public var defaultLanguage: String?
    public var languages: [String]?

    public init(defaultLanguage: String? = nil, languages: [String]? = nil) {
        self.defaultLanguage = defaultLanguage
        self.languages = languages
    }

    public var resolvedDefaultLanguage: String { defaultLanguage ?? "en" }

    public var resolvedLanguages: [String] {
        if let languages, languages.isEmpty == false { return languages }
        return [resolvedDefaultLanguage]
    }
}
