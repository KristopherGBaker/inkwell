import Foundation
import XCTest
@testable import BlogCore

final class CollectionsTests: XCTestCase {
    func testLoadsMultipleCollectionsByConfig() throws {
        let root = makeTempProject()
        try writeFile(root, "content/posts/hello.md", """
        ---
        title: Hi
        slug: hi
        date: 2026-01-01
        ---
        body
        """)
        try writeFile(root, "content/projects/wolt.md", """
        ---
        title: Wolt
        slug: wolt
        year: 2023
        ---
        body
        """)
        let configs = [
            CollectionConfig(id: "posts", dir: "content/posts", route: "/posts"),
            CollectionConfig(id: "projects", dir: "content/projects", route: "/work", sortBy: "year")
        ]
        let collections = try ContentLoader().loadCollections(configs, in: root)
        XCTAssertEqual(collections["posts"]?.items.count, 1)
        XCTAssertEqual(collections["posts"]?.items.first?.slug, "hi")
        XCTAssertEqual(collections["projects"]?.items.count, 1)
        XCTAssertEqual(collections["projects"]?.items.first?.frontMatter["year"] as? Int, 2023)
    }

    func testProjectsCollectionEmitsListAndDetailRoutes() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "https://krisbaker.com/",
          "collections": [
            { "id": "posts", "dir": "content/posts", "route": "/posts" },
            { "id": "projects", "dir": "content/projects", "route": "/work", "sortBy": "year", "taxonomies": ["tags"] }
          ]
        }
        """)
        try writeFile(root, "content/posts/2026-03-05-hello.md", """
        ---
        title: Hello
        slug: hello
        date: 2026-03-05T00:00:00Z
        ---
        Body
        """)
        try writeFile(root, "content/projects/wolt.md", """
        ---
        title: Wolt
        slug: wolt
        year: 2023
        summary: Membership
        tags: [iOS]
        ---
        Project body
        """)

        _ = try BuildPipeline().run(in: root)

        XCTAssertTrue(fileExists(root, "docs/posts/hello/index.html"))
        XCTAssertTrue(fileExists(root, "docs/posts/index.html"))
        XCTAssertTrue(fileExists(root, "docs/work/index.html"))
        XCTAssertTrue(fileExists(root, "docs/work/wolt/index.html"))
    }

    func testEmitsCollectionScopedTaxonomyRoutes() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "https://example.com/",
          "collections": [
            { "id": "projects", "dir": "content/projects", "route": "/work", "sortBy": "year", "taxonomies": ["tags"] }
          ]
        }
        """)
        try writeFile(root, "content/projects/wolt.md", """
        ---
        title: Wolt
        slug: wolt
        year: 2023
        tags: [swift]
        ---
        body
        """)

        _ = try BuildPipeline().run(in: root)

        XCTAssertTrue(fileExists(root, "docs/work/tags/swift/index.html"))
        XCTAssertFalse(fileExists(root, "docs/tags/swift/index.html"))
    }

    func testFallsBackToImplicitPostsCollectionWhenConfigOmits() throws {
        // No `collections` in config → today's URL structure is preserved.
        let root = try makeTempBlogProject()
        try writeFile(root, "content/posts/2026-03-05-hello.md", """
        ---
        title: Hello
        slug: hello
        date: 2026-03-05T00:00:00Z
        tags: [swift]
        ---
        Body
        """)
        _ = try BuildPipeline().run(in: root)
        XCTAssertTrue(fileExists(root, "docs/posts/hello/index.html"))
        XCTAssertTrue(fileExists(root, "docs/tags/swift/index.html"))
        XCTAssertTrue(fileExists(root, "docs/archive/index.html"))
    }

    private func writeBlogConfig(_ root: URL, _ content: String) throws {
        try content.write(to: root.appendingPathComponent("blog.config.json"), atomically: true, encoding: .utf8)
    }

    private func writeFile(_ root: URL, _ relative: String, _ content: String) throws {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func fileExists(_ root: URL, _ relative: String) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(relative).path)
    }

    private func makeTempProject() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
