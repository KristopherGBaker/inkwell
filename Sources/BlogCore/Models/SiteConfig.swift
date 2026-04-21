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

    public init(title: String, baseURL: String = "/", theme: String = "default", outputDir: String = "docs", description: String? = nil, tagline: String? = nil, searchEnabled: Bool? = nil, head: String? = nil) {
        self.title = title
        self.baseURL = baseURL
        self.theme = theme
        self.outputDir = outputDir
        self.description = description
        self.tagline = tagline
        self.searchEnabled = searchEnabled
        self.head = head
    }
}
