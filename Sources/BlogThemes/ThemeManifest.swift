import Foundation

public struct ThemeManifest: Codable, Equatable {
    public let name: String
    public let version: String
    public let compatibleCore: String

    public init(name: String, version: String, compatibleCore: String) {
        self.name = name
        self.version = version
        self.compatibleCore = compatibleCore
    }
}
