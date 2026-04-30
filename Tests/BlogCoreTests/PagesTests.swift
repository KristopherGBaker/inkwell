import Foundation
import XCTest
@testable import BlogCore

final class PagesTests: XCTestCase {
    func testLoadsContentPagesAndEmitsRouteFromPath() throws {
        let root = try makeTempBlogProject()
        try writeFile(root, "content/pages/about.md", """
        ---
        title: About
        layout: page
        ---
        About me.
        """)

        _ = try BuildPipeline().run(in: root)
        XCTAssertTrue(fileExists(root, "docs/about/index.html"))
        let html = try String(contentsOf: root.appendingPathComponent("docs/about/index.html"))
        XCTAssertTrue(html.contains("About"))
        XCTAssertTrue(html.contains("About me."))
    }

    func testNestedPagePathBecomesRoute() throws {
        let root = try makeTempBlogProject()
        try writeFile(root, "content/pages/now/index.md", """
        ---
        title: Now
        ---
        Currently.
        """)

        _ = try BuildPipeline().run(in: root)
        XCTAssertTrue(fileExists(root, "docs/now/index.html"))
    }

    func testPageWithCustomLayoutResolvesTemplateInTheme() throws {
        let root = try makeTempBlogProject()
        try writeFile(root, "content/pages/resume.md", """
        ---
        title: Résumé
        layout: resume
        ---
        """)

        // Override the resume layout in the project's themes folder so the
        // renderer resolves it without needing a bundled template.
        try writeFile(root, "themes/default/templates/layouts/resume.html", """
        RESUME-PAGE:{{ page.title }}:{{ data.experience.0.org }}
        """)

        try writeFile(root, "data/experience.yml", """
        - org: Wolt
          role: Senior Engineer
        """)

        _ = try BuildPipeline().run(in: root)
        let html = try String(contentsOf: root.appendingPathComponent("docs/resume/index.html"))
        XCTAssertTrue(html.contains("RESUME-PAGE:Résumé:Wolt"), "Got: \(html)")
    }

    func testPageRouteHelperHandlesIndexAndNestedPaths() {
        XCTAssertEqual(ContentLoader.pageRoute(fromRelativePath: "about.md"), "/about/")
        XCTAssertEqual(ContentLoader.pageRoute(fromRelativePath: "now/index.md"), "/now/")
        XCTAssertEqual(ContentLoader.pageRoute(fromRelativePath: "projects/wolt.md"), "/projects/wolt/")
        XCTAssertEqual(ContentLoader.pageRoute(fromRelativePath: "index.md"), "/")
    }

    private func writeFile(_ root: URL, _ relative: String, _ content: String) throws {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func fileExists(_ root: URL, _ relative: String) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(relative).path)
    }
}
