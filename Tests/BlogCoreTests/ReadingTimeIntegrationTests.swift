import Foundation
import XCTest
@testable import BlogCore

final class ReadingTimeIntegrationTests: XCTestCase {
    func testPostHTMLContainsReadingTimeLabel() throws {
        let temp = try makeTempBlogProject()
        let words = Array(repeating: "word", count: 800).joined(separator: " ")
        let post = """
        ---
        title: Long Read
        date: 2026-04-12T00:00:00Z
        slug: long-read
        ---

        \(words)
        """
        try post.write(
            to: temp.appendingPathComponent("content/posts/2026-04-12-long-read.md"),
            atomically: true,
            encoding: .utf8
        )

        let report = try BuildPipeline().run(in: temp)
        XCTAssertEqual(report.errors.count, 0)

        let postHTML = try String(contentsOf: temp.appendingPathComponent("docs/posts/long-read/index.html"))
        XCTAssertTrue(postHTML.contains("4 min read"), "post header should show formatted reading time, got: \(postHTML.prefix(800))")
    }

    func testShortPostSuppressesReadingTimeLabel() throws {
        let temp = try makeTempBlogProject()
        let post = """
        ---
        title: Empty
        date: 2026-04-12T00:00:00Z
        slug: empty
        ---

        """
        try post.write(
            to: temp.appendingPathComponent("content/posts/2026-04-12-empty.md"),
            atomically: true,
            encoding: .utf8
        )

        let report = try BuildPipeline().run(in: temp)
        XCTAssertEqual(report.errors.count, 0)
        let postHTML = try String(contentsOf: temp.appendingPathComponent("docs/posts/empty/index.html"))
        XCTAssertFalse(postHTML.contains("min read"), "empty body should suppress the label")
    }

    func testTranslationOverlayChangesReadingTimeLabel() throws {
        let temp = try makeTempBlogProject(extraDirectories: ["content/posts"])

        let config = """
        {
          "title": "Bilingual",
          "baseURL": "/",
          "theme": "quiet",
          "outputDir": "docs",
          "i18n": { "defaultLanguage": "en", "languages": ["en", "ja"] },
          "themeCopy": { "readingTimeLabel": "%d min read" },
          "translations": {
            "ja": {
              "themeCopy": { "readingTimeLabel": "%d 分で読了" }
            }
          },
          "collections": [
            { "id": "posts", "dir": "content/posts", "route": "posts" }
          ]
        }
        """
        try config.write(
            to: temp.appendingPathComponent("blog.config.json"),
            atomically: true,
            encoding: .utf8
        )

        let words = Array(repeating: "word", count: 800).joined(separator: " ")
        let englishPost = """
        ---
        title: Long
        date: 2026-04-12T00:00:00Z
        slug: long
        ---

        \(words)
        """
        try englishPost.write(
            to: temp.appendingPathComponent("content/posts/long.md"),
            atomically: true,
            encoding: .utf8
        )
        let japanesePost = """
        ---
        title: Long JA
        date: 2026-04-12T00:00:00Z
        slug: long
        lang: ja
        ---

        \(words)
        """
        try japanesePost.write(
            to: temp.appendingPathComponent("content/posts/long.ja.md"),
            atomically: true,
            encoding: .utf8
        )

        let report = try BuildPipeline().run(in: temp)
        XCTAssertEqual(report.errors.count, 0)

        let englishHTML = try String(contentsOf: temp.appendingPathComponent("docs/posts/long/index.html"))
        XCTAssertTrue(englishHTML.contains("4 min read"))

        let japaneseHTML = try String(contentsOf: temp.appendingPathComponent("docs/ja/posts/long/index.html"))
        XCTAssertTrue(japaneseHTML.contains("4 分で読了"), "Japanese overlay should translate the label, got: \(japaneseHTML.prefix(800))")
    }
}
