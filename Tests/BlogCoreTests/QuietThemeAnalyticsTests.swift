import Foundation
import XCTest
@testable import BlogCore

final class QuietThemeAnalyticsTests: XCTestCase {
    func testRendersUmamiScriptTagFromConfigInBuildMode() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "/",
          "theme": "quiet",
          "analytics": {
            "umami": {
              "scriptUrl": "https://analytics.krisbaker.com/script.js",
              "websiteId": "abc-123",
              "hostUrl": "https://analytics.krisbaker.com",
              "domains": "krisbaker.com",
              "respectDoNotTrack": true,
              "tag": "site"
            }
          }
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

        _ = try BuildPipeline().run(in: root, mode: .build)
        let html = try String(contentsOf: root.appendingPathComponent("docs/index.html"))

        XCTAssertTrue(
            html.contains("src=\"https://analytics.krisbaker.com/script.js\""),
            "Expected the prod script URL on the rendered tag. Got:\n\(html)"
        )
        XCTAssertTrue(html.contains("data-website-id=\"abc-123\""), "Got:\n\(html)")
        XCTAssertTrue(html.contains("data-host-url=\"https://analytics.krisbaker.com\""), "Got:\n\(html)")
        XCTAssertTrue(html.contains("data-domains=\"krisbaker.com\""), "Got:\n\(html)")
        XCTAssertTrue(html.contains("data-do-not-track=\"true\""), "Got:\n\(html)")
        XCTAssertTrue(html.contains("data-tag=\"site\""), "Got:\n\(html)")
    }

    func testServeModeUsesLocalUmamiBlockWhenPresent() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "/",
          "theme": "quiet",
          "analytics": {
            "umami": {
              "scriptUrl": "https://analytics.krisbaker.com/script.js",
              "websiteId": "prod-id",
              "domains": "krisbaker.com",
              "local": {
                "scriptUrl": "http://localhost:3000/script.js",
                "websiteId": "local-id",
                "domains": "localhost"
              }
            }
          }
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

        _ = try BuildPipeline().run(in: root, mode: .serve)
        let html = try String(contentsOf: root.appendingPathComponent("docs/index.html"))

        XCTAssertTrue(
            html.contains("src=\"http://localhost:3000/script.js\""),
            "serve mode must point at the localhost Umami when a `local` block is present. Got:\n\(html)"
        )
        XCTAssertTrue(html.contains("data-website-id=\"local-id\""), "Got:\n\(html)")
        XCTAssertTrue(html.contains("data-domains=\"localhost\""), "Got:\n\(html)")
        XCTAssertFalse(
            html.contains("analytics.krisbaker.com"),
            "serve mode must not leak the prod script URL. Got:\n\(html)"
        )
        XCTAssertFalse(
            html.contains("data-website-id=\"prod-id\""),
            "serve mode must not leak the prod website ID. Got:\n\(html)"
        )
    }

    func testServeModeWithoutLocalBlockOmitsScriptEntirely() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "/",
          "theme": "quiet",
          "analytics": {
            "umami": {
              "scriptUrl": "https://analytics.krisbaker.com/script.js",
              "websiteId": "prod-id",
              "domains": "krisbaker.com"
            }
          }
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

        _ = try BuildPipeline().run(in: root, mode: .serve)
        let html = try String(contentsOf: root.appendingPathComponent("docs/index.html"))

        XCTAssertFalse(
            html.contains("data-website-id"),
            // swiftlint:disable:next line_length
            "serve mode without a `local` block must emit no script tag at all — that's the safety guarantee. Got:\n\(html)"
        )
        XCTAssertFalse(html.contains("analytics.krisbaker.com"), "Got:\n\(html)")
    }

    func testNoAnalyticsConfigOmitsScriptInBuildMode() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "/",
          "theme": "quiet"
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

        _ = try BuildPipeline().run(in: root, mode: .build)
        let html = try String(contentsOf: root.appendingPathComponent("docs/index.html"))

        XCTAssertFalse(html.contains("data-website-id"), "Got:\n\(html)")
    }

    func testOptionalDataAttributesAreOmittedWhenUnset() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "/",
          "theme": "quiet",
          "analytics": {
            "umami": {
              "scriptUrl": "https://x/s.js",
              "websiteId": "id"
            }
          }
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

        _ = try BuildPipeline().run(in: root, mode: .build)
        let html = try String(contentsOf: root.appendingPathComponent("docs/index.html"))

        XCTAssertTrue(html.contains("data-website-id=\"id\""))
        XCTAssertFalse(html.contains("data-host-url"), "Optional data-host-url shouldn't render when hostUrl is unset")
        XCTAssertFalse(html.contains("data-domains"), "Optional data-domains shouldn't render when domains is unset")
        // swiftlint:disable:next line_length
        XCTAssertFalse(html.contains("data-do-not-track"), "Optional data-do-not-track shouldn't render when respectDoNotTrack is unset")
        XCTAssertFalse(html.contains("data-tag"), "Optional data-tag shouldn't render when tag is unset")
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
