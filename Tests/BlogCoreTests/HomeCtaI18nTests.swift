import Foundation
import XCTest
@testable import BlogCore

final class HomeCtaI18nTests: XCTestCase {
    func testLocalizesInternalRoutesWithoutChangingExternalLinks() throws {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, """
        {
          "title": "Kris",
          "baseURL": "https://example.com/site/",
          "i18n": { "defaultLanguage": "en", "languages": ["en", "ja"] },
          "home": {
            "template": "landing",
            "heroPrimaryCta": { "label": "Work", "href": "/work/" },
            "heroSecondaryCta": { "label": "External", "href": "https://example.org/" },
            "featuredCta": { "label": "Projects", "href": "/projects/" },
            "recentCta": { "label": "Posts", "href": "/posts/" },
            "buildingCta": { "label": "CDN", "href": "//cdn.example.com/" },
            "aboutLinks": [
              { "label": "About", "href": "/about/" },
              { "label": "Email", "href": "mailto:hello@example.com" },
              { "label": "Section", "href": "#section" }
            ]
          },
          "collections": [
            { "id": "posts", "dir": "content/posts", "route": "/posts" }
          ]
        }
        """)
        try writeFile(root, "themes/default/templates/layouts/landing.html", """
        {{ home.heroPrimaryCta.href }}
        {{ home.heroSecondaryCta.href }}
        {{ home.featuredCta.href }}
        {{ home.recentCta.href }}
        {{ home.buildingCta.href }}
        {% for link in home.aboutLinks %}{{ link.href }}\n{% endfor %}
        """)
        try writeFile(root, "themes/default/templates/layouts/post-list.html", "list")
        try writeFile(root, "themes/default/templates/layouts/redirect.html", "redirect")

        _ = try BuildPipeline().run(in: root)

        let enHome = try String(contentsOfFile: root.appendingPathComponent("docs/index.html").path)
        let jaHome = try String(contentsOfFile: root.appendingPathComponent("docs/ja/index.html").path)

        XCTAssertTrue(enHome.contains("/site/work/"))
        XCTAssertTrue(enHome.contains("/site/about/"))
        XCTAssertTrue(jaHome.contains("/site/ja/work/"))
        XCTAssertTrue(jaHome.contains("/site/ja/about/"))
        XCTAssertTrue(jaHome.contains("/site/ja/projects/"))
        XCTAssertTrue(jaHome.contains("/site/ja/posts/"))
        XCTAssertTrue(jaHome.contains("https://example.org/"))
        XCTAssertTrue(jaHome.contains("//cdn.example.com/"))
        XCTAssertTrue(jaHome.contains("mailto:hello@example.com"))
        XCTAssertTrue(jaHome.contains("#section"))
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
        // swiftlint:disable:next line_length
        try FileManager.default.createDirectory(at: root.appendingPathComponent("content/posts"), withIntermediateDirectories: true)
        return root
    }
}
