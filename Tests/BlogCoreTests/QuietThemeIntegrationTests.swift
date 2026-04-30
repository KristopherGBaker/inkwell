import Foundation
import XCTest
@testable import BlogCore

final class QuietThemeIntegrationTests: XCTestCase {
    func testQuietThemeRendersLandingFromConfig() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "/",
          "theme": "quiet",
          "author": { "name": "Kristopher Baker", "role": "Senior Engineer", "location": "Tokyo" },
          "home": { "template": "landing", "featuredCollection": "projects", "featuredCount": 4, "recentCollection": "posts", "recentCount": 2 },
          "collections": [
            { "id": "posts", "dir": "content/posts", "route": "/posts" },
            { "id": "projects", "dir": "content/projects", "route": "/work", "sortBy": "year", "taxonomies": ["tags"] }
          ]
        }
        """)
        try writeFile(root, "content/projects/wolt.md", """
        ---
        title: Wolt Membership
        slug: wolt
        year: 2023
        org: Wolt / DoorDash
        summary: Membership funnel work
        ---
        """)

        _ = try BuildPipeline().run(in: root)
        let html = try String(contentsOf: root.appendingPathComponent("docs/index.html"))
        XCTAssertTrue(html.contains("Selected work"), "Got:\n\(html)")
        XCTAssertTrue(html.contains("/work/wolt/"), "Got:\n\(html)")
        XCTAssertTrue(html.contains("tokens.css"), "Quiet head injection should reference tokens.css")
    }

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

    func testQuietThemeCaseStudyShowsMetricsFromFrontMatter() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "/",
          "theme": "quiet",
          "collections": [
            { "id": "projects", "dir": "content/projects", "route": "/work", "sortBy": "year", "detailTemplate": "layouts/case-study" }
          ]
        }
        """)
        try writeFile(root, "content/projects/wolt.md", """
        ---
        title: Wolt Membership
        slug: wolt
        year: 2023
        summary: Funnel rebuild
        metrics:
          - label: Subscribers added
            value: "+27k"
          - label: Conversion lift
            value: "+29.8%"
        ---
        Project body.
        """)

        _ = try BuildPipeline().run(in: root)
        let html = try String(contentsOf: root.appendingPathComponent("docs/work/wolt/index.html"))
        XCTAssertTrue(html.contains("+27k"), "Got:\n\(html)")
        XCTAssertTrue(html.contains("Subscribers added"), "Got:\n\(html)")
    }

    func testQuietThemeRendersNavAndAuthorFromConfig() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "/",
          "theme": "quiet",
          "author": {
            "name": "Kristopher Baker",
            "social": [{ "label": "GitHub", "url": "https://github.com/x" }]
          },
          "nav": [
            { "label": "Work", "route": "/work/" },
            { "label": "Writing", "route": "/posts/" }
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

        _ = try BuildPipeline().run(in: root)
        let html = try String(contentsOf: root.appendingPathComponent("docs/index.html"))
        XCTAssertTrue(html.contains("href=\"/work/\""), "Top bar should render nav items, got:\n\(html)")
        XCTAssertTrue(html.contains(">Work</a>"), "Top bar should render nav label, got:\n\(html)")
        XCTAssertTrue(html.contains("https://github.com/x"), "Footer should render author social link, got:\n\(html)")
        XCTAssertTrue(html.contains("Kristopher Baker"), "Footer should render author name, got:\n\(html)")
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
