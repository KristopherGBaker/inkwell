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

    public init(
        name: String,
        role: String? = nil,
        location: String? = nil,
        email: String? = nil,
        social: [SocialLink]? = nil
    ) {
        self.name = name
        self.role = role
        self.location = location
        self.email = email
        self.social = social
    }
}
