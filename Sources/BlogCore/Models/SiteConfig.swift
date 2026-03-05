import Foundation

public struct SiteConfig: Codable, Equatable {
    public var title: String
    public var baseURL: String
    public var theme: String
    public var outputDir: String

    public init(title: String, baseURL: String = "/", theme: String = "default", outputDir: String = "docs") {
        self.title = title
        self.baseURL = baseURL
        self.theme = theme
        self.outputDir = outputDir
    }
}
