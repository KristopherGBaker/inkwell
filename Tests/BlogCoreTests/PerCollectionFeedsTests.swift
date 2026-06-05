import Foundation
import XCTest
@testable import BlogCore

/// Covers the `feeds` config: per-collection feeds, a combined root feed,
/// child-collection item links, year-based dates, autodiscovery, and the
/// no-config back-compat path.
final class PerCollectionFeedsTests: XCTestCase {
    func testPerCollectionAndCombinedFeedsAreEmitted() throws {
        let root = try makeMultiCollectionProject()
        _ = try BuildPipeline().run(in: root)

        // Per-collection feed files exist under each collection's route.
        for path in [
            "docs/posts/rss.xml", "docs/posts/atom.xml", "docs/posts/feed.json",
            "docs/work/rss.xml", "docs/work/atom.xml", "docs/work/feed.json",
            "docs/building/rss.xml", "docs/building/atom.xml", "docs/building/feed.json"
        ] {
            XCTAssertTrue(fileExists(root, path), "expected feed at \(path)")
        }

        // Combined feed lives at the root and carries items from every collection.
        let combined = try read(root, "docs/rss.xml")
        XCTAssertTrue(combined.contains("Hello post"))
        XCTAssertTrue(combined.contains("Alpha case study"))
        XCTAssertTrue(combined.contains("First update"))
    }

    func testCombinedFeedIsNewestFirstAcrossCollections() throws {
        let root = try makeMultiCollectionProject()
        _ = try BuildPipeline().run(in: root)

        let combined = try read(root, "docs/rss.xml")
        let post = try XCTUnwrap(combined.range(of: "Hello post"))       // 2026-03-01
        let update = try XCTUnwrap(combined.range(of: "First update"))   // 2026-02-01
        let work = try XCTUnwrap(combined.range(of: "Alpha case study")) // year 2025 -> 2025-01-01
        XCTAssertTrue(post.lowerBound < update.lowerBound)
        XCTAssertTrue(update.lowerBound < work.lowerBound)
    }

    func testCollectionFeedOnlyHasItsOwnItems() throws {
        let root = try makeMultiCollectionProject()
        _ = try BuildPipeline().run(in: root)

        let posts = try read(root, "docs/posts/rss.xml")
        XCTAssertTrue(posts.contains("Hello post"))
        XCTAssertFalse(posts.contains("Alpha case study"), "posts feed must not include work items")
        XCTAssertFalse(posts.contains("First update"), "posts feed must not include building updates")

        // Self link reflects the collection's own location.
        XCTAssertTrue(posts.contains(#"href="https://krisbaker.com/posts/rss.xml" rel="self""#))
    }

    func testChildUpdateLinksRouteUnderParentProject() throws {
        let root = try makeMultiCollectionProject()
        _ = try BuildPipeline().run(in: root)

        let building = try read(root, "docs/building/rss.xml")
        XCTAssertTrue(building.contains("First update"))
        XCTAssertTrue(
            building.contains("https://krisbaker.com/building/proj/first-update/"),
            "update link must route under its parent project, got: \(building)"
        )
        XCTAssertFalse(building.contains("https://krisbaker.com/building/first-update/"))
    }

    func testWorkItemWithOnlyYearGetsDerivedDate() throws {
        let root = try makeMultiCollectionProject()
        _ = try BuildPipeline().run(in: root)

        let work = try read(root, "docs/work/rss.xml")
        XCTAssertTrue(work.contains("Alpha case study"))
        XCTAssertTrue(work.contains("01 Jan 2025"), "year should derive a Jan 1 pubDate, got: \(work)")
    }

    func testHeadAdvertisesPerCollectionFeeds() throws {
        let root = try makeMultiCollectionProject()
        _ = try BuildPipeline().run(in: root)

        let page = try read(root, "docs/work/index.html")
        XCTAssertTrue(page.contains(#"href="/posts/rss.xml""#))
        XCTAssertTrue(page.contains(#"href="/work/rss.xml""#))
        XCTAssertTrue(page.contains(#"href="/building/rss.xml""#))
    }

    func testNoFeedsConfigEmitsSingleRootFeedOnly() throws {
        let root = try makeTempProject()
        try writeFile(root, "blog.config.json", """
        {
          "title": "Kris",
          "baseURL": "https://krisbaker.com/",
          "theme": "quiet",
          "collections": [
            { "id": "posts", "dir": "content/posts", "route": "/posts" }
          ]
        }
        """)
        try writeFile(root, "content/posts/hello.md", """
        ---
        title: Hello post
        slug: hello
        date: 2026-03-01T00:00:00Z
        ---
        Body
        """)
        _ = try BuildPipeline().run(in: root)

        XCTAssertTrue(fileExists(root, "docs/rss.xml"))
        XCTAssertFalse(fileExists(root, "docs/posts/rss.xml"), "no feeds block -> no per-collection feeds")
    }

    // MARK: - Fixtures

    private func makeMultiCollectionProject() throws -> URL {
        let root = try makeTempProject()
        try writeFile(root, "blog.config.json", """
        {
          "title": "Kris",
          "baseURL": "https://krisbaker.com/",
          "author": { "name": "Kris Baker", "email": "kris@krisbaker.com" },
          "theme": "quiet",
          "feeds": { "combined": true, "collections": ["posts", "projects", "updates"] },
          "collections": [
            { "id": "posts", "dir": "content/posts", "route": "/posts" },
            {
              "id": "projects", "dir": "content/projects", "route": "/work",
              "sortBy": "order", "sortOrder": "asc",
              "listTemplate": "layouts/work-list", "detailTemplate": "layouts/case-study"
            },
            {
              "id": "building", "dir": "content/building", "route": "/building",
              "sortBy": "order", "sortOrder": "asc",
              "listTemplate": "layouts/building-list", "detailTemplate": "layouts/building"
            },
            {
              "id": "updates", "dir": "content/updates", "route": "/building",
              "parent": "building", "parentField": "project",
              "sortBy": "date", "sortOrder": "desc", "detailTemplate": "layouts/update"
            }
          ]
        }
        """)
        try writeFile(root, "content/posts/hello.md", """
        ---
        title: Hello post
        slug: hello
        date: 2026-03-01T00:00:00Z
        summary: A short summary.
        ---
        This is the post body.
        """)
        try writeFile(root, "content/projects/alpha.md", """
        ---
        title: Alpha case study
        slug: alpha
        year: 2025
        order: 1
        summary: A work case study dated by year.
        ---
        The case study body.
        """)
        try writeFile(root, "content/building/proj.md", """
        ---
        title: Proj
        slug: proj
        order: 1
        status: active
        summary: A building project.
        ---
        Project overview.
        """)
        try writeFile(root, "content/updates/2026-02-01-first.md", """
        ---
        title: First update
        slug: first-update
        date: 2026-02-01T00:00:00Z
        project: proj
        status: shipped
        ---
        The first update body.
        """)
        return root
    }

    private func makeTempProject() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        for dir in ["content/posts", "content/projects", "content/building", "content/updates", "content/pages"] {
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent(dir),
                withIntermediateDirectories: true
            )
        }
        return root
    }

    private func writeFile(_ root: URL, _ relative: String, _ content: String) throws {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func read(_ root: URL, _ relative: String) throws -> String {
        try String(contentsOfFile: root.appendingPathComponent(relative).path, encoding: .utf8)
    }

    private func fileExists(_ root: URL, _ relative: String) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(relative).path)
    }
}
