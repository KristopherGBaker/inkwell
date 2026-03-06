import Foundation

public struct PostDocument: Equatable {
    public let frontMatter: PostFrontMatter
    public let body: String
    public let sourcePath: URL

    public init(frontMatter: PostFrontMatter, body: String, sourcePath: URL) {
        self.frontMatter = frontMatter
        self.body = body
        self.sourcePath = sourcePath
    }
}
