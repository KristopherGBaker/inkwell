public protocol MarkdownEngine {
    func render(_ markdown: String) throws -> String
}
