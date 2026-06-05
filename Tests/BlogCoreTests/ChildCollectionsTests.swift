import Foundation
import XCTest
@testable import BlogCore

final class ChildCollectionsTests: XCTestCase {
    func testUpdatesRouteUnderTheirParentProject() throws {
        let root = try makeBuildingProject()
        _ = try BuildPipeline().run(in: root)

        XCTAssertTrue(fileExists(root, "docs/building/index.html"))
        XCTAssertTrue(fileExists(root, "docs/building/shikisha/index.html"))
        XCTAssertTrue(fileExists(root, "docs/building/shikisha/2026-06-04-streaming/index.html"))
        XCTAssertTrue(fileExists(root, "docs/building/shikisha/2026-05-20-first-run/index.html"))
        // Child collection does not get its own list or top-level detail routes.
        XCTAssertFalse(fileExists(root, "docs/updates/index.html"))
        XCTAssertFalse(fileExists(root, "docs/building/2026-06-04-streaming/index.html"))
    }

    func testProjectDetailListsItsUpdatesNewestFirst() throws {
        let root = try makeBuildingProject()
        _ = try BuildPipeline().run(in: root)

        let html = try readFile(root, "docs/building/shikisha/index.html")
        guard let newest = html.range(of: "Streaming tool calls"),
              let oldest = html.range(of: "First end-to-end run") else {
            return XCTFail("expected both update titles on the project page")
        }
        XCTAssertTrue(newest.lowerBound < oldest.lowerBound, "updates should be newest-first")
        XCTAssertTrue(html.contains("update-timeline"))
        XCTAssertTrue(html.contains("status-line"))
        XCTAssertTrue(html.contains("updated "), "expected a relative recency label")
    }

    func testStandaloneUpdateLinksBackToProject() throws {
        let root = try makeBuildingProject()
        _ = try BuildPipeline().run(in: root)

        let html = try readFile(root, "docs/building/shikisha/2026-06-04-streaming/index.html")
        XCTAssertTrue(html.contains("/building/shikisha/"), "update should link back to its project")
        XCTAssertTrue(html.contains("Shikisha"))
        // Newest update has an older sibling but no newer one.
        XCTAssertTrue(html.contains("/building/shikisha/2026-05-20-first-run/"))
    }

    func testHomeShowsWhatImBuildingFeed() throws {
        let root = try makeBuildingProject()
        _ = try BuildPipeline().run(in: root)

        let html = try readFile(root, "docs/index.html")
        XCTAssertTrue(html.contains("building-feed"))
        XCTAssertTrue(html.contains("What I'm building"))
        XCTAssertTrue(html.contains("Streaming tool calls"))
        XCTAssertTrue(html.contains("Shikisha"))
    }

    func testHomeBuildingLabelIsLocalized() throws {
        let root = try makeBuildingProject(localized: true)
        _ = try BuildPipeline().run(in: root)

        let ja = try readFile(root, "docs/ja/index.html")
        XCTAssertTrue(ja.contains("制作中のもの"), "JA home should use the translated building label")
    }

    func testBuildingNextLinkUsesBuildingCopyNotCaseStudy() throws {
        let root = try makeBuildingProject()
        // A second project gives the first one a "next" link to render.
        try writeFile(root, "content/building/inkwell.md", """
        ---
        title: Inkwell
        slug: inkwell
        order: 2
        status: active
        summary: A static publishing tool.
        tags: [Swift]
        ---
        Inkwell overview body.
        """)
        _ = try BuildPipeline().run(in: root)

        let html = try readFile(root, "docs/building/shikisha/index.html")
        XCTAssertTrue(html.contains("case-study-next"), "building detail should render a next link")
        XCTAssertTrue(html.contains("See the build log"), "building next CTA should use building copy")
        XCTAssertFalse(html.contains("Read case study"), "building next CTA should not reuse case-study copy")
    }

    func testOrphanUpdateIsReportedByCheck() throws {
        let root = try makeBuildingProject()
        try writeFile(root, "content/updates/2026-06-10-orphan.md", """
        ---
        title: Orphan update
        slug: 2026-06-10-orphan
        date: 2026-06-10T00:00:00Z
        project: does-not-exist
        ---
        Body
        """)

        let result = ProjectChecker().check(projectRoot: root)
        XCTAssertTrue(
            result.errors.contains { $0.contains("does-not-exist") },
            "check should flag updates pointing at a missing project: \(result.errors)"
        )
    }

    // MARK: - Fixtures

    private func makeBuildingProject(localized: Bool = false) throws -> URL {
        let root = try makeTempBlogProject()
        try writeBlogConfig(root, buildingConfig(localized: localized))
        try writeFile(root, "content/building/shikisha.md", """
        ---
        title: Shikisha
        slug: shikisha
        order: 1
        status: active
        summary: A Swift engine for orchestrating LLM workflows.
        tags: [Swift, LLM]
        ---
        Shikisha overview body.
        """)
        try writeFile(root, "content/updates/2026-06-04-streaming.md", """
        ---
        title: Streaming tool calls
        slug: 2026-06-04-streaming
        date: 2026-06-04T00:00:00Z
        project: shikisha
        status: shipped
        ---
        Wired streaming through the workflow runner.
        """)
        try writeFile(root, "content/updates/2026-05-20-first-run.md", """
        ---
        title: First end-to-end run
        slug: 2026-05-20-first-run
        date: 2026-05-20T00:00:00Z
        project: shikisha
        status: note
        ---
        First full workflow executed end to end.
        """)
        return root
    }

    private func buildingConfig(localized: Bool) -> String {
        let i18n = localized ? """
          "i18n": { "defaultLanguage": "en", "languages": ["en", "ja"] },
          "translations": { "ja": { "home": { "buildingLabel": "制作中のもの" } } },
        """ : ""
        return """
        {
          "title": "Kris",
          "baseURL": "https://krisbaker.com/",
          "theme": "quiet",
        \(i18n)
          "home": {
            "template": "landing",
            "buildingCollection": "updates",
            "buildingCount": 3,
            "buildingLabel": "What I'm building"
          },
          "collections": [
            {
              "id": "building", "dir": "content/building", "route": "/building",
              "sortBy": "order", "sortOrder": "asc", "taxonomies": ["tags"],
              "listTemplate": "layouts/building-list", "detailTemplate": "layouts/building"
            },
            {
              "id": "updates", "dir": "content/updates", "route": "/building",
              "parent": "building", "parentField": "project",
              "sortBy": "date", "sortOrder": "desc", "taxonomies": [],
              "detailTemplate": "layouts/update"
            }
          ]
        }
        """
    }

    private func writeBlogConfig(_ root: URL, _ content: String) throws {
        try content.write(to: root.appendingPathComponent("blog.config.json"), atomically: true, encoding: .utf8)
    }

    private func writeFile(_ root: URL, _ relative: String, _ content: String) throws {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func readFile(_ root: URL, _ relative: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    private func fileExists(_ root: URL, _ relative: String) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(relative).path)
    }
}
