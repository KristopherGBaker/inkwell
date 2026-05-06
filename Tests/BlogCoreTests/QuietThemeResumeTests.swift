import Foundation
import XCTest
@testable import BlogCore

final class QuietThemeResumeTests: XCTestCase {
    func testQuietThemeRendersResumeFromDataFiles() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "/",
          "theme": "quiet",
          "author": { "name": "Kristopher Baker", "role": "Senior Software Engineer", "location": "Tokyo" },
          "collections": []
        }
        """)
        try writeFile(root, "data/experience.yml", """
        - org: Wolt
          role: Senior Engineer
          years: "2023 — Now"
          bullets:
            - Did stuff
        """)
        try writeFile(root, "content/pages/resume.md", """
        ---
        title: Résumé
        layout: resume
        ---
        """)

        _ = try BuildPipeline().run(in: root)
        let html = try String(contentsOf: root.appendingPathComponent("docs/resume/index.html"))
        XCTAssertTrue(html.contains("Wolt"), "Got:\n\(html)")
        XCTAssertTrue(html.contains("2023 — Now"), "Got:\n\(html)")
        XCTAssertTrue(html.contains("Print / Save as PDF"), "Got:\n\(html)")
    }

    func testQuietResumeUsesDownloadLinkWhenPDFConfigured() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "/",
          "theme": "quiet",
          "author": { "name": "Kristopher Baker" },
          "collections": []
        }
        """)
        try writeFile(root, "data/resume.yml", """
        pdf: /resume.pdf
        """)
        try writeFile(root, "data/experience.yml", """
        - org: Wolt
          role: Senior Engineer
          years: "2023 — Now"
        """)
        try writeFile(root, "content/pages/resume.md", """
        ---
        title: Résumé
        layout: resume
        ---
        """)

        _ = try BuildPipeline().run(in: root)
        let html = try String(contentsOf: root.appendingPathComponent("docs/resume/index.html"))
        XCTAssertTrue(
            html.contains("href=\"/resume.pdf\""),
            "Expected toolbar to be a download link when data.resume.pdf is set. Got:\n\(html)"
        )
        XCTAssertTrue(
            html.contains("download"),
            "Expected the link to carry the `download` attribute. Got:\n\(html)"
        )
        XCTAssertFalse(
            html.contains("window.print()"),
            "Print button should not render when a PDF is configured. Got:\n\(html)"
        )
    }

    func testQuietResumePicksUpPerLanguagePDFs() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "/",
          "theme": "quiet",
          "author": { "name": "Kristopher Baker" },
          "collections": [
            { "id": "posts", "dir": "content/posts", "route": "/posts" }
          ],
          "i18n": { "defaultLanguage": "en", "languages": ["en", "ja"] }
        }
        """)
        try writeFile(root, "data/resume.yml", """
        pdf: /resume-en.pdf
        """)
        try writeFile(root, "data/resume.ja.yml", """
        pdf: /resume-ja.pdf
        """)
        try writeFile(root, "data/experience.yml", """
        - org: Wolt
          role: Senior Engineer
          years: "2023 — Now"
        """)
        try writeFile(root, "content/pages/resume.md", """
        ---
        title: Résumé
        layout: resume
        ---
        """)
        try writeFile(root, "content/pages/resume.ja.md", """
        ---
        title: 履歴書
        layout: resume
        ---
        """)

        _ = try BuildPipeline().run(in: root)
        let englishHTML = try String(contentsOf: root.appendingPathComponent("docs/resume/index.html"))
        let japaneseHTML = try String(contentsOf: root.appendingPathComponent("docs/ja/resume/index.html"))

        XCTAssertTrue(
            englishHTML.contains("href=\"/resume-en.pdf\""),
            "Default-language resume should link to /resume-en.pdf. Got:\n\(englishHTML)"
        )
        XCTAssertTrue(
            japaneseHTML.contains("href=\"/resume-ja.pdf\""),
            "Japanese resume should link to /resume-ja.pdf via data/resume.ja.yml. Got:\n\(japaneseHTML)"
        )
        XCTAssertFalse(
            japaneseHTML.contains("/resume-en.pdf"),
            "Japanese resume should not leak the EN PDF. Got:\n\(japaneseHTML)"
        )
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
