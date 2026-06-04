import Foundation
import XCTest
@testable import BlogCore

/// Rendering tests for the opt-in `analytics.umami.events` layer: the inline
/// auto-tracker (outbound links + downloads) and the declarative
/// `data-umami-event` attributes on the quiet theme's CTAs. Page-view-only
/// behavior lives in `QuietThemeAnalyticsTests`.
final class QuietThemeEventsTests: XCTestCase {
    func testEventsAutoTrackerRendersWhenOutboundOrDownloadEnabled() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "/",
          "theme": "quiet",
          "analytics": {
            "umami": {
              "scriptUrl": "https://x/s.js",
              "websiteId": "id",
              "events": { "outboundLinks": true, "downloads": true }
            }
          }
        }
        """)
        try writeHelloPost(root)

        _ = try BuildPipeline().run(in: root, mode: .build)
        let html = try String(contentsOf: root.appendingPathComponent("docs/index.html"))

        XCTAssertTrue(html.contains("umami.track(\"outbound-link\""), "Got:\n\(html)")
        XCTAssertTrue(html.contains("umami.track(\"download\""), "Got:\n\(html)")
        XCTAssertTrue(html.contains("\"pdf\""), "Default download extensions should render. Got:\n\(html)")
    }

    func testEventsAutoTrackerOmittedWhenNoEventsBlock() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "/",
          "theme": "quiet",
          "analytics": {
            "umami": { "scriptUrl": "https://x/s.js", "websiteId": "id" }
          }
        }
        """)
        try writeHelloPost(root)

        _ = try BuildPipeline().run(in: root, mode: .build)
        let html = try String(contentsOf: root.appendingPathComponent("docs/index.html"))

        XCTAssertTrue(html.contains("data-website-id=\"id\""), "Page-view tag should still render. Got:\n\(html)")
        XCTAssertFalse(html.contains("umami.track("), "No auto-tracker without an events block. Got:\n\(html)")
    }

    func testCustomDownloadExtensionsOverrideDefault() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "/",
          "theme": "quiet",
          "analytics": {
            "umami": {
              "scriptUrl": "https://x/s.js",
              "websiteId": "id",
              "events": { "downloads": true, "downloadExtensions": ["pdf", "key"] }
            }
          }
        }
        """)
        try writeHelloPost(root)

        _ = try BuildPipeline().run(in: root, mode: .build)
        let html = try String(contentsOf: root.appendingPathComponent("docs/index.html"))

        XCTAssertTrue(html.contains("\"key\""), "Custom extension should render. Got:\n\(html)")
        // swiftlint:disable:next line_length
        XCTAssertFalse(html.contains("\"zip\""), "Default-only extensions should not render when overridden. Got:\n\(html)")
    }

    func testThemeElementsRenderDeclarativeEventAttributes() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "/",
          "theme": "quiet",
          "author": {
            "name": "Kris",
            "email": "hello@krisbaker.com",
            "social": [{ "label": "GitHub", "url": "https://github.com/x" }]
          },
          "analytics": {
            "umami": {
              "scriptUrl": "https://x/s.js",
              "websiteId": "id",
              "events": { "themeElements": true }
            }
          }
        }
        """)
        try writeHelloPost(root)

        _ = try BuildPipeline().run(in: root, mode: .build)
        let html = try String(contentsOf: root.appendingPathComponent("docs/index.html"))

        XCTAssertTrue(html.contains("data-umami-event=\"email\""), "Got:\n\(html)")
        XCTAssertTrue(html.contains("data-umami-event=\"social\""), "Got:\n\(html)")
        XCTAssertTrue(html.contains("data-umami-event-network=\"GitHub\""), "Got:\n\(html)")
    }

    func testThemeElementsAttributesOmittedWhenFlagOff() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "/",
          "theme": "quiet",
          "author": {
            "name": "Kris",
            "email": "hello@krisbaker.com",
            "social": [{ "label": "GitHub", "url": "https://github.com/x" }]
          },
          "analytics": {
            "umami": {
              "scriptUrl": "https://x/s.js",
              "websiteId": "id",
              "events": { "outboundLinks": true }
            }
          }
        }
        """)
        try writeHelloPost(root)

        _ = try BuildPipeline().run(in: root, mode: .build)
        let html = try String(contentsOf: root.appendingPathComponent("docs/index.html"))

        XCTAssertFalse(
            html.contains("data-umami-event"),
            "themeElements is off, so no declarative attributes should render. Got:\n\(html)"
        )
    }

    func testServeModeWithoutLocalOmitsEventTracker() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "/",
          "theme": "quiet",
          "analytics": {
            "umami": {
              "scriptUrl": "https://x/s.js",
              "websiteId": "id",
              "events": { "outboundLinks": true, "themeElements": true }
            }
          }
        }
        """)
        try writeHelloPost(root)

        _ = try BuildPipeline().run(in: root, mode: .serve)
        let html = try String(contentsOf: root.appendingPathComponent("docs/index.html"))

        XCTAssertFalse(html.contains("umami.track("), "serve without local must emit no tracker. Got:\n\(html)")
        XCTAssertFalse(html.contains("data-umami-event"), "serve without local must emit no event attrs. Got:\n\(html)")
    }

    private func writeHelloPost(_ root: URL) throws {
        try writeFile(root, "content/posts/2026-03-05-hello.md", """
        ---
        title: Hello
        slug: hello
        date: 2026-03-05T00:00:00Z
        ---
        Body
        """)
    }

    private func writeBlogConfig(_ root: URL, _ content: String) throws {
        try content.write(to: root.appendingPathComponent("blog.config.json"), atomically: true, encoding: .utf8)
    }

    private func writeFile(_ root: URL, _ relative: String, _ content: String) throws {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
