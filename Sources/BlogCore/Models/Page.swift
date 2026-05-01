import Foundation

public struct Page {
    public var route: String
    public var layout: String
    public var title: String?
    public var summary: String?
    public var frontMatter: [String: Any]
    public var body: String
    public var sourcePath: URL
    public var lang: String
    public var availableLanguages: [String]

    public init(
        route: String,
        layout: String,
        title: String? = nil,
        summary: String? = nil,
        frontMatter: [String: Any] = [:],
        body: String = "",
        sourcePath: URL = URL(fileURLWithPath: "/dev/null"),
        lang: String = "en",
        availableLanguages: [String] = ["en"]
    ) {
        self.route = route
        self.layout = layout
        self.title = title
        self.summary = summary
        self.frontMatter = frontMatter
        self.body = body
        self.sourcePath = sourcePath
        self.lang = lang
        self.availableLanguages = availableLanguages
    }
}
