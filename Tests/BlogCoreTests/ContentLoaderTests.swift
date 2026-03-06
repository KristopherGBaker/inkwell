import Foundation
import XCTest
@testable import BlogCore

final class ContentLoaderTests: XCTestCase {
    func testLoadsStructuredFrontMatterFromYAML() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("content/posts"), withIntermediateDirectories: true)

        let markdown = """
        ---
        title: YAML Example
        date: 2026-03-06T00:00:00Z
        slug: yaml-example
        summary: "Handles: colons and arrays"
        tags:
          - swift
          - notes
        categories: [engineering, personal]
        draft: false
        coverImage: /assets/images/example.png
        ---

        Hello world
        """

        try markdown.write(to: root.appendingPathComponent("content/posts/2026-03-06-yaml-example.md"), atomically: true, encoding: .utf8)

        let posts = try ContentLoader().loadPosts(in: root)
        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(posts[0].frontMatter.slug, "yaml-example")
        XCTAssertEqual(posts[0].frontMatter.tags ?? [], ["swift", "notes"])
        XCTAssertEqual(posts[0].frontMatter.categories ?? [], ["engineering", "personal"])
        XCTAssertEqual(posts[0].frontMatter.coverImage, "/assets/images/example.png")
    }
}
