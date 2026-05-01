import Foundation

public struct HomeCta: Codable, Equatable {
    public var label: String
    public var href: String

    public init(label: String, href: String) {
        self.label = label
        self.href = href
    }
}
