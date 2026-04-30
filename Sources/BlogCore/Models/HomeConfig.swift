import Foundation

public struct HomeConfig: Codable, Equatable {
    public var template: String
    public var featuredCollection: String?
    public var featuredCount: Int?
    public var recentCollection: String?
    public var recentCount: Int?

    public init(
        template: String,
        featuredCollection: String? = nil,
        featuredCount: Int? = nil,
        recentCollection: String? = nil,
        recentCount: Int? = nil
    ) {
        self.template = template
        self.featuredCollection = featuredCollection
        self.featuredCount = featuredCount
        self.recentCollection = recentCollection
        self.recentCount = recentCount
    }
}
