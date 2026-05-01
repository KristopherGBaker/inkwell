import Foundation
import XCTest
@testable import BlogCore

final class I18nRoutingTests: XCTestCase {
    func testEmitsPerLanguagePlansForCollections() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "https://krisbaker.com/",
          "i18n": { "defaultLanguage": "en", "languages": ["en", "ja"] },
          "collections": [
            { "id": "posts", "dir": "content/posts", "route": "/posts" }
          ]
        }
        """)
        try writeFile(root, "content/posts/hello.md", """
        ---
        title: Hello
        slug: hello
        date: 2026-01-01T00:00:00Z
        ---
        en body
        """)
        try writeFile(root, "content/posts/hello.ja.md", """
        ---
        title: こんにちは
        slug: hello
        date: 2026-01-01T00:00:00Z
        ---
        ja body
        """)

        _ = try BuildPipeline().run(in: root)

        // Default language at canonical route
        XCTAssertTrue(fileExists(root, "docs/posts/hello/index.html"), "en post")
        // Non-default at /<lang>/ prefix
        XCTAssertTrue(fileExists(root, "docs/ja/posts/hello/index.html"), "ja post")
        // Lang-prefixed listing pages
        XCTAssertTrue(fileExists(root, "docs/posts/index.html"), "en list")
        XCTAssertTrue(fileExists(root, "docs/ja/posts/index.html"), "ja list")
    }

    func testEmitsPerLanguagePagesAndPrefixesURLs() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "https://krisbaker.com/",
          "i18n": { "defaultLanguage": "en", "languages": ["en", "ja"] },
          "collections": [
            { "id": "posts", "dir": "content/posts", "route": "/posts" }
          ]
        }
        """)
        try writeFile(root, "content/pages/about.md", """
        ---
        title: About
        ---
        about en
        """)
        try writeFile(root, "content/pages/about.ja.md", """
        ---
        title: 自己紹介
        ---
        about ja
        """)

        _ = try BuildPipeline().run(in: root)

        XCTAssertTrue(fileExists(root, "docs/about/index.html"))
        XCTAssertTrue(fileExists(root, "docs/ja/about/index.html"))
    }

    func testEmitsDefaultLangAliasRedirects() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "https://krisbaker.com/",
          "i18n": { "defaultLanguage": "en", "languages": ["en", "ja"] },
          "collections": [
            { "id": "posts", "dir": "content/posts", "route": "/posts" }
          ]
        }
        """)
        try writeFile(root, "content/posts/hello.md", """
        ---
        title: Hello
        slug: hello
        date: 2026-01-01T00:00:00Z
        ---
        Body
        """)

        _ = try BuildPipeline().run(in: root)

        // Canonical URL still at root
        XCTAssertTrue(fileExists(root, "docs/posts/hello/index.html"))
        // /en/ alias also emitted
        XCTAssertTrue(fileExists(root, "docs/en/posts/hello/index.html"))

        let alias = try String(contentsOfFile: root.appendingPathComponent("docs/en/posts/hello/index.html").path)
        XCTAssertTrue(alias.contains("http-equiv=\"refresh\""), "should be a meta-refresh redirect")
        XCTAssertTrue(alias.contains("/posts/hello/"), "should reference the canonical URL")
        XCTAssertTrue(alias.contains("rel=\"canonical\""), "should include canonical link")
    }

    func testMonolingualSiteUnchanged() throws {
        // Without an i18n block, no /ja/ prefix should be generated.
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "https://krisbaker.com/",
          "collections": [
            { "id": "posts", "dir": "content/posts", "route": "/posts" }
          ]
        }
        """)
        try writeFile(root, "content/posts/hello.md", """
        ---
        title: Hello
        slug: hello
        date: 2026-01-01T00:00:00Z
        ---
        en body
        """)

        _ = try BuildPipeline().run(in: root)

        XCTAssertTrue(fileExists(root, "docs/posts/hello/index.html"))
        XCTAssertFalse(fileExists(root, "docs/ja/posts/hello/index.html"))
        XCTAssertFalse(fileExists(root, "docs/en/posts/hello/index.html"))
    }

    func testTranslationsOverlayAppliesPerLanguage() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "https://krisbaker.com/",
          "theme": "quiet",
          "heroHeadline": "I build *millions* of...",
          "i18n": { "defaultLanguage": "en", "languages": ["en", "ja"] },
          "footerCta": { "eyebrow": "Get in touch", "headline": "Quietly open to good work." },
          "home": { "template": "landing" },
          "collections": [
            { "id": "posts", "dir": "content/posts", "route": "/posts" }
          ],
          "translations": {
            "ja": {
              "heroHeadline": "数百万人のための...",
              "footerCta": { "headline": "良い仕事に静かに開いています。" }
            }
          }
        }
        """)

        _ = try BuildPipeline().run(in: root)

        let enHome = try String(contentsOfFile: root.appendingPathComponent("docs/index.html").path)
        let jaHome = try String(contentsOfFile: root.appendingPathComponent("docs/ja/index.html").path)

        XCTAssertTrue(enHome.contains("I build"), "en hero present")
        XCTAssertTrue(enHome.contains("Quietly open to good work."), "en footer headline present")
        XCTAssertTrue(jaHome.contains("数百万人"), "ja hero override applied")
        XCTAssertTrue(jaHome.contains("良い仕事に静かに開いています。"), "ja footer override applied")
        XCTAssertTrue(jaHome.contains("Get in touch"), "ja footer eyebrow falls back to default")
    }

    // MARK: - Helpers

    private func writeBlogConfig(_ root: URL, _ json: String) throws {
        try json.write(to: root.appendingPathComponent("blog.config.json"), atomically: true, encoding: .utf8)
    }

    private func writeFile(_ root: URL, _ relative: String, _ content: String) throws {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func makeTempBlogProject() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("content/posts"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("content/pages"), withIntermediateDirectories: true)
        return root
    }

    private func fileExists(_ root: URL, _ relative: String) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(relative).path)
    }
}
