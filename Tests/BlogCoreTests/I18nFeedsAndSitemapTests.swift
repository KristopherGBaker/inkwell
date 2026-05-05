import Foundation
import XCTest
@testable import BlogCore

final class I18nFeedsAndSitemapTests: XCTestCase {
    // MARK: - Sitemap

    func testSitemapDeclaresXhtmlNamespaceWhenI18nEnabled() throws {
        let root = try setupBilingualPostsProject()
        _ = try BuildPipeline().run(in: root)

        let sitemap = try readSitemap(root)
        XCTAssertTrue(sitemap.contains("xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\""))
        XCTAssertTrue(
            sitemap.contains("xmlns:xhtml=\"http://www.w3.org/1999/xhtml\""),
            "i18n sitemaps need the xhtml namespace for hreflang alternates"
        )
    }

    func testSitemapEmitsHreflangAlternatesPerURL() throws {
        let root = try setupBilingualPostsProject()
        _ = try BuildPipeline().run(in: root)

        let sitemap = try readSitemap(root)

        // Default-language detail URL must list en self, ja, x-default
        let enLoc = "<loc>https://krisbaker.com/posts/hello/</loc>"
        XCTAssertTrue(sitemap.contains(enLoc))

        let enBlock = block(in: sitemap, containing: enLoc)
        XCTAssertTrue(
            enBlock.contains(#"hreflang="en" href="https://krisbaker.com/posts/hello/""#),
            "en block must self-reference"
        )
        XCTAssertTrue(
            enBlock.contains(#"hreflang="ja" href="https://krisbaker.com/ja/posts/hello/""#),
            "en block must point at ja translation"
        )
        XCTAssertTrue(
            enBlock.contains(#"hreflang="x-default" href="https://krisbaker.com/posts/hello/""#),
            "en block must include x-default"
        )

        // Same alternates appear on the ja URL block
        let jaLoc = "<loc>https://krisbaker.com/ja/posts/hello/</loc>"
        XCTAssertTrue(sitemap.contains(jaLoc))
        let jaBlock = block(in: sitemap, containing: jaLoc)
        XCTAssertTrue(jaBlock.contains(#"hreflang="en" href="https://krisbaker.com/posts/hello/""#))
        XCTAssertTrue(jaBlock.contains(#"hreflang="ja" href="https://krisbaker.com/ja/posts/hello/""#))
        XCTAssertTrue(jaBlock.contains(#"hreflang="x-default" href="https://krisbaker.com/posts/hello/""#))
    }

    func testSitemapOmitsDefaultLanguageRedirectAliasRoutes() throws {
        // /en/posts/hello/ is emitted as a meta-refresh redirect to the
        // canonical /posts/hello/. It must NOT appear in the sitemap or the
        // crawler will see two URLs claiming to be the same canonical.
        let root = try setupBilingualPostsProject()
        _ = try BuildPipeline().run(in: root)

        let sitemap = try readSitemap(root)
        XCTAssertFalse(
            sitemap.contains("<loc>https://krisbaker.com/en/posts/hello/</loc>"),
            "default-language alias redirect must be excluded from sitemap"
        )
    }

    func testMonolingualSitemapOmitsHreflangAlternates() throws {
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
        Body
        """)

        _ = try BuildPipeline().run(in: root)

        let sitemap = try readSitemap(root)
        XCTAssertFalse(sitemap.contains("xmlns:xhtml"))
        XCTAssertFalse(sitemap.contains("xhtml:link"))
    }

    // MARK: - RSS

    func testEmitsDefaultAndPerLanguageRSSFeeds() throws {
        let root = try setupBilingualPostsProject()
        _ = try BuildPipeline().run(in: root)

        XCTAssertTrue(fileExists(root, "docs/rss.xml"), "default-language feed at /rss.xml")
        XCTAssertTrue(fileExists(root, "docs/ja/rss.xml"), "ja feed at /ja/rss.xml")
    }

    func testRSSPerLanguageItemsUseLanguagePrefixedURLs() throws {
        let root = try setupBilingualPostsProject()
        _ = try BuildPipeline().run(in: root)

        let enFeed = try readFeed(root, lang: nil)
        let jaFeed = try readFeed(root, lang: "ja")

        XCTAssertTrue(enFeed.contains("<link>https://krisbaker.com/posts/hello/</link>"))
        XCTAssertFalse(enFeed.contains("https://krisbaker.com/ja/posts/hello/"))

        XCTAssertTrue(jaFeed.contains("<link>https://krisbaker.com/ja/posts/hello/</link>"))
        XCTAssertFalse(jaFeed.contains("<link>https://krisbaker.com/posts/hello/</link>"))
    }

    func testRSSExcludesItemsWithoutTranslation() throws {
        // `lonely.md` has no .ja.md companion. /ja/rss.xml must not include it
        // since subscribers expect every entry in the feed to be in Japanese.
        let root = try makeTempBlogProject()
        try writeBilingualConfig(root)
        try writeFile(root, "content/posts/hello.md", """
        ---
        title: Hello
        slug: hello
        date: 2026-01-01T00:00:00Z
        ---
        en
        """)
        try writeFile(root, "content/posts/hello.ja.md", """
        ---
        title: こんにちは
        slug: hello
        date: 2026-01-01T00:00:00Z
        ---
        ja
        """)
        try writeFile(root, "content/posts/lonely.md", """
        ---
        title: Lonely
        slug: lonely
        date: 2026-01-02T00:00:00Z
        ---
        en only
        """)

        _ = try BuildPipeline().run(in: root)

        let jaFeed = try readFeed(root, lang: "ja")
        XCTAssertTrue(jaFeed.contains("<title>こんにちは</title>"))
        XCTAssertFalse(jaFeed.contains("Lonely"), "ja feed must not include en-only items")
        XCTAssertFalse(jaFeed.contains("/posts/lonely/"))
    }

    func testRSSMonolingualSiteEmitsOnlyDefaultFeed() throws {
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
        Body
        """)

        _ = try BuildPipeline().run(in: root)

        XCTAssertTrue(fileExists(root, "docs/rss.xml"))
        XCTAssertFalse(fileExists(root, "docs/ja/rss.xml"))
    }

    // MARK: - Helpers

    private func setupBilingualPostsProject() throws -> URL {
        let root = try makeTempBlogProject()
        try writeBilingualConfig(root)
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
        return root
    }

    private func writeBilingualConfig(_ root: URL) throws {
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
    }

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

    private func readSitemap(_ root: URL) throws -> String {
        try String(contentsOfFile: root.appendingPathComponent("docs/sitemap.xml").path)
    }

    private func readFeed(_ root: URL, lang: String?) throws -> String {
        let path = lang.map { "docs/\($0)/rss.xml" } ?? "docs/rss.xml"
        return try String(contentsOfFile: root.appendingPathComponent(path).path)
    }

    /// Returns the `<url>...</url>` block in `sitemap` that contains `needle`.
    private func block(in sitemap: String, containing needle: String) -> String {
        guard let needleRange = sitemap.range(of: needle) else { return "" }
        let before = sitemap[..<needleRange.lowerBound]
        let after = sitemap[needleRange.upperBound...]
        guard let openIndex = before.range(of: "<url>", options: .backwards)?.lowerBound,
              let closeIndex = after.range(of: "</url>")?.upperBound
        else { return "" }
        return String(sitemap[openIndex..<closeIndex])
    }
}
