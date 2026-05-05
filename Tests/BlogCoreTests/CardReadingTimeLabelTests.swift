import Foundation
import XCTest
@testable import BlogCore

final class CardReadingTimeLabelTests: XCTestCase {
    func testHomeCardsExposeReadingTimeLabelTranslated() throws {
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
              "themeCopy": { "readingTimeLabel": "約%d分" }
            }
          },
          "collections": [
            { "id": "posts", "dir": "content/posts", "route": "posts" }
          ],
          "home": {
            "template": "landing",
            "recentCollection": "posts",
            "recentCount": 1
          }
        }
        """
        try config.write(
            to: temp.appendingPathComponent("blog.config.json"),
            atomically: true,
            encoding: .utf8
        )

        let body = Array(repeating: "word", count: 800).joined(separator: " ")
        let englishPost = """
        ---
        title: Long
        date: 2026-04-12T00:00:00Z
        slug: long
        ---

        \(body)
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

        \(body)
        """
        try japanesePost.write(
            to: temp.appendingPathComponent("content/posts/long.ja.md"),
            atomically: true,
            encoding: .utf8
        )

        let report = try BuildPipeline().run(in: temp)
        XCTAssertEqual(report.errors.count, 0)

        let englishHome = try String(contentsOf: temp.appendingPathComponent("docs/index.html"))
        XCTAssertTrue(englishHome.contains("4 min read"), "EN home card should use base format, got: \(englishHome.prefix(2400))")

        let japaneseHome = try String(contentsOf: temp.appendingPathComponent("docs/ja/index.html"))
        XCTAssertTrue(japaneseHome.contains("約4分"), "JA home card should use translated format, got: \(japaneseHome.prefix(2400))")
    }
}
