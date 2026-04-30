import Foundation
import XCTest
@testable import BlogCore

final class HomePageTests: XCTestCase {
    func testHomeUsesConfiguredTemplateAndPullsFeaturedFromCollection() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "https://krisbaker.com/",
          "home": {
            "template": "landing",
            "featuredCollection": "projects",
            "featuredCount": 4,
            "recentCollection": "posts",
            "recentCount": 2
          },
          "collections": [
            { "id": "posts", "dir": "content/posts", "route": "/posts" },
            { "id": "projects", "dir": "content/projects", "route": "/work", "sortBy": "year" }
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
        ---
        Body
        """)

        // Override the landing layout to print featured + recent so the
        // test can verify the context shape regardless of theme styling.
        try writeFile(root, "themes/default/templates/layouts/landing.html", """
        FEATURED:{% for f in home.featured %}{{ f.title }}{% endfor %}|RECENT:{% for r in home.recent %}{{ r.title }}{% endfor %}
        """)

        _ = try BuildPipeline().run(in: root)
        let html = try String(contentsOf: root.appendingPathComponent("docs/index.html"))
        XCTAssertTrue(html.contains("FEATURED:Wolt"), "Got: \(html)")
        XCTAssertTrue(html.contains("RECENT:Hello"), "Got: \(html)")
    }

    func testHomeFallsBackToPaginatedPostListWhenHomeOmitted() throws {
        // Today's behavior preserved when no `home` key in config.
        let root = try makeTempBlogProject()
        try writeFile(root, "content/posts/2026-03-05-hello.md", """
        ---
        title: Hello
        slug: hello
        date: 2026-03-05T00:00:00Z
        ---
        Body
        """)
        _ = try BuildPipeline().run(in: root)
        XCTAssertTrue(fileExists(root, "docs/index.html"))
        let html = try String(contentsOf: root.appendingPathComponent("docs/index.html"))
        XCTAssertTrue(html.contains("/posts/hello/"))
        XCTAssertTrue(html.contains("href=\"/archive/\""))
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
}
