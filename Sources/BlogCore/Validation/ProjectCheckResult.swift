import Foundation

public struct ProjectCheckResult {
    public let brokenLinks: [String]
    public let errors: [String]

    public var isValid: Bool { brokenLinks.isEmpty && errors.isEmpty }

    public init(brokenLinks: [String], errors: [String]) {
        self.brokenLinks = brokenLinks
        self.errors = errors
    }
}
