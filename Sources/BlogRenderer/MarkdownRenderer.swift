import Foundation

public struct MarkdownRenderer {
    private let engine: MarkdownEngine

    public init(engine: MarkdownEngine = GFMEngine()) {
        self.engine = engine
    }

    public func render(_ markdown: String) throws -> String {
        try engine.render(markdown)
    }
}
