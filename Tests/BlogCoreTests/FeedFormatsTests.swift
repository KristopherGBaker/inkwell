import Foundation
import XCTest
@testable import BlogCore

/// Covers feed correctness (RFC-822 dates, self links, generator), full
/// content, localized channel metadata, and the Atom + JSON Feed formats.
final class FeedFormatsTests: XCTestCase {
    // MARK: - RSS correctness

    func testRSSPubDateIsRFC822NotISO8601() throws {
        let root = try setupBilingualProject()
        _ = try BuildPipeline().run(in: root)

        let rss = try read(root, "docs/rss.xml")
        XCTAssertTrue(rss.contains("<pubDate>Thu, 01 Jan 2026 00:00:00 +0000</pubDate>"), rss)
        XCTAssertFalse(
            rss.contains("<pubDate>2026-01-01T00:00:00Z</pubDate>"),
            "pubDate must be RFC-822, not raw ISO-8601"
        )
    }

    func testRSSChannelHasSelfLinkGeneratorAndLastBuildDate() throws {
        let root = try setupBilingualProject()
        _ = try BuildPipeline().run(in: root)

        let rss = try read(root, "docs/rss.xml")
        XCTAssertTrue(rss.contains(#"xmlns:atom="http://www.w3.org/2005/Atom""#))
        let selfLink = #"<atom:link href="https://krisbaker.com/rss.xml" rel="self" type="application/rss+xml"/>"#
        XCTAssertTrue(rss.contains(selfLink))
        XCTAssertTrue(rss.contains("<generator>Inkwell"))
        XCTAssertTrue(rss.contains("<lastBuildDate>"))

        let jaRSS = try read(root, "docs/ja/rss.xml")
        XCTAssertTrue(jaRSS.contains(#"<atom:link href="https://krisbaker.com/ja/rss.xml" rel="self""#))
    }

    func testRSSIncludesContentEncodedWithRenderedBody() throws {
        let root = try setupBilingualProject()
        _ = try BuildPipeline().run(in: root)

        let rss = try read(root, "docs/rss.xml")
        XCTAssertTrue(rss.contains(#"xmlns:content="http://purl.org/rss/1.0/modules/content/""#))
        XCTAssertTrue(rss.contains("<content:encoded><![CDATA["))
        XCTAssertTrue(rss.contains("the full english body"), "feed should carry the rendered post body")
    }

    func testFeedContentAbsolutizesRootRelativeURLs() throws {
        let root = try makeTempBlogProject()
        try writeBilingualConfig(root)
        try writeFile(root, "content/posts/hello.md", """
        ---
        title: Hello
        slug: hello
        date: 2026-01-01T00:00:00Z
        ---
        See the [about page](/about/) for more.
        """)
        try writeFile(root, "content/posts/hello.ja.md", """
        ---
        title: こんにちは
        slug: hello
        date: 2026-01-01T00:00:00Z
        ---
        詳しくは[アバウト](/about/)へ。
        """)

        _ = try BuildPipeline().run(in: root)

        let rss = try read(root, "docs/rss.xml")
        XCTAssertTrue(
            rss.contains(#"href="https://krisbaker.com/about/""#),
            "root-relative links in feed content must be absolutized"
        )
    }

    // MARK: - Localized channel metadata

    func testChannelDescriptionIsLocalizedPerLanguage() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "https://krisbaker.com/",
          "description": "Notes in English",
          "i18n": { "defaultLanguage": "en", "languages": ["en", "ja"] },
          "translations": { "ja": { "description": "日本語のノート" } },
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

        _ = try BuildPipeline().run(in: root)

        let enRSS = try read(root, "docs/rss.xml")
        let jaRSS = try read(root, "docs/ja/rss.xml")
        XCTAssertTrue(enRSS.contains("<description>Notes in English</description>"))
        XCTAssertTrue(jaRSS.contains("<description>日本語のノート</description>"))
        XCTAssertFalse(jaRSS.contains("Recent entries from"), "ja channel must not fall back to English")
    }

    // MARK: - Atom

    func testEmitsAtomFeedsPerLanguage() throws {
        let root = try setupBilingualProject()
        _ = try BuildPipeline().run(in: root)

        XCTAssertTrue(fileExists(root, "docs/atom.xml"))
        XCTAssertTrue(fileExists(root, "docs/ja/atom.xml"))
    }

    func testAtomFeedStructure() throws {
        let root = try setupBilingualProject()
        _ = try BuildPipeline().run(in: root)

        let atom = try read(root, "docs/atom.xml")
        XCTAssertTrue(atom.contains(#"<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en">"#))
        let selfLink = #"<link href="https://krisbaker.com/atom.xml" rel="self" type="application/atom+xml"/>"#
        XCTAssertTrue(atom.contains(selfLink))
        XCTAssertTrue(atom.contains("<updated>2026-01-01T00:00:00Z</updated>"))
        XCTAssertTrue(atom.contains("<id>https://krisbaker.com/posts/hello/</id>"))
        XCTAssertTrue(atom.contains(#"<content type="html"><![CDATA["#))
        XCTAssertTrue(atom.contains("<author>"))
        XCTAssertTrue(atom.contains("<name>Kris Baker</name>"))
    }

    // MARK: - JSON Feed

    func testEmitsJSONFeedsPerLanguage() throws {
        let root = try setupBilingualProject()
        _ = try BuildPipeline().run(in: root)

        XCTAssertTrue(fileExists(root, "docs/feed.json"))
        XCTAssertTrue(fileExists(root, "docs/ja/feed.json"))
    }

    func testJSONFeedIsValidVersion11WithItems() throws {
        let root = try setupBilingualProject()
        _ = try BuildPipeline().run(in: root)

        let data = try Data(contentsOf: root.appendingPathComponent("docs/feed.json"))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["version"] as? String, "https://jsonfeed.org/version/1.1")
        XCTAssertEqual(json["home_page_url"] as? String, "https://krisbaker.com/")
        XCTAssertEqual(json["feed_url"] as? String, "https://krisbaker.com/feed.json")

        let items = try XCTUnwrap(json["items"] as? [[String: Any]])
        XCTAssertEqual(items.count, 1)
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item["url"] as? String, "https://krisbaker.com/posts/hello/")
        XCTAssertEqual(item["id"] as? String, "https://krisbaker.com/posts/hello/")
        XCTAssertEqual(item["date_published"] as? String, "2026-01-01T00:00:00Z")
        let contentHTML = try XCTUnwrap(item["content_html"] as? String)
        XCTAssertTrue(contentHTML.contains("the full english body"))
    }

    // MARK: - Autodiscovery

    func testRenderedHeadHasFeedAutodiscoveryLinks() throws {
        let root = try setupBilingualProject()
        _ = try BuildPipeline().run(in: root)

        let page = try read(root, "docs/posts/hello/index.html")
        XCTAssertTrue(page.contains(#"<link rel="alternate" type="application/rss+xml""#))
        XCTAssertTrue(page.contains(#"href="/rss.xml""#))
        XCTAssertTrue(page.contains(#"type="application/atom+xml""#))
        XCTAssertTrue(page.contains(#"type="application/feed+json""#))

        let jaPage = try read(root, "docs/ja/posts/hello/index.html")
        XCTAssertTrue(jaPage.contains(#"href="/ja/rss.xml""#), "ja pages point at the ja feed")
    }

    // MARK: - Monolingual

    func testMonolingualSiteStillEmitsAllThreeFormats() throws {
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
        XCTAssertTrue(fileExists(root, "docs/atom.xml"))
        XCTAssertTrue(fileExists(root, "docs/feed.json"))
        XCTAssertFalse(fileExists(root, "docs/ja/rss.xml"))
        // No <language> tag on a monolingual RSS channel.
        let rss = try read(root, "docs/rss.xml")
        XCTAssertFalse(rss.contains("<language>"))
    }

    // MARK: - Helpers

    private func setupBilingualProject() throws -> URL {
        let root = try makeTempBlogProject()
        try writeBilingualConfig(root)
        try writeFile(root, "content/posts/hello.md", """
        ---
        title: Hello
        slug: hello
        date: 2026-01-01T00:00:00Z
        summary: A short summary.
        ---
        This is the full english body.
        """)
        try writeFile(root, "content/posts/hello.ja.md", """
        ---
        title: こんにちは
        slug: hello
        date: 2026-01-01T00:00:00Z
        summary: 短い要約。
        ---
        これは日本語の本文です。
        """)
        return root
    }

    private func writeBilingualConfig(_ root: URL) throws {
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "https://krisbaker.com/",
          "author": { "name": "Kris Baker", "email": "kris@krisbaker.com" },
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
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("content/posts"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("content/pages"),
            withIntermediateDirectories: true
        )
        return root
    }

    private func fileExists(_ root: URL, _ relative: String) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(relative).path)
    }

    private func read(_ root: URL, _ relative: String) throws -> String {
        try String(contentsOfFile: root.appendingPathComponent(relative).path, encoding: .utf8)
    }
}
