import Foundation

public struct FooterCtaConfig: Codable, Equatable {
    public var eyebrow: String?
    public var headline: String?

    public init(eyebrow: String? = nil, headline: String? = nil) {
        self.eyebrow = eyebrow
        self.headline = headline
    }
}
