import Foundation
import XCTest
@testable import BlogCore

final class ProjectCheckerTests: XCTestCase {
    func testMissingCoverImageProducesError() throws {
        let root = try makeProjectRoot()
        try writePost(
            to: root,
            named: "2026-03-08-missing-cover.md",
            markdown: """
            ---
            title: Missing Cover
            date: 2026-03-08T00:00:00Z
            slug: missing-cover
            coverImage: /assets/images/missing.png
            ---

            Body
            """
        )

        let result = ProjectChecker().check(projectRoot: root)

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.brokenLinks, [])
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertTrue(result.errors[0].contains("missing.png"))
    }

    func testMalformedConfigProducesError() throws {
        let root = try makeProjectRoot()
        let invalidJSON = """
        {
          "title": 42
        }
        """
        try invalidJSON.write(to: root.appendingPathComponent("blog.config.json"), atomically: true, encoding: .utf8)

        let result = ProjectChecker().check(projectRoot: root)

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.brokenLinks, [])
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertTrue(result.errors[0].contains("blog.config.json"))
    }

    func testRootRelativeCoverImageResolvesFromPublicDirectory() throws {
        let root = try makeProjectRoot()
        try FileManager.default.createDirectory(at: root.appendingPathComponent("public/images"), withIntermediateDirectories: true)
        try Data("image".utf8).write(to: root.appendingPathComponent("public/images/cover.jpg"))
        try writePost(
            to: root,
            named: "2026-03-08-public-cover.md",
            markdown: """
            ---
            title: Public Cover
            date: 2026-03-08T00:00:00Z
            slug: public-cover
            coverImage: /images/cover.jpg
            ---

            Body
            """
        )

        let result = ProjectChecker().check(projectRoot: root)

        XCTAssertTrue(result.errors.isEmpty)
    }

    func testCheckerUsesConfiguredOutputDirectoryForLinkValidation() throws {
        let root = try makeProjectRoot()
        try writeConfig(
            to: root,
            json: """
            {
              "title": "My Blog",
              "baseURL": "/",
              "theme": "default",
              "outputDir": "public-site"
            }
            """
        )
        try FileManager.default.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("public-site/posts/test"), withIntermediateDirectories: true)
        try "<a href=\"/missing/\">missing</a>".write(to: root.appendingPathComponent("docs/index.html"), atomically: true, encoding: .utf8)
        try "<a href=\"/posts/test/\">test</a>".write(to: root.appendingPathComponent("public-site/index.html"), atomically: true, encoding: .utf8)
        try "<h1>Test</h1>".write(to: root.appendingPathComponent("public-site/posts/test/index.html"), atomically: true, encoding: .utf8)

        let result = ProjectChecker().check(projectRoot: root)

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.brokenLinks, [])
    }

    func testCheckerUsesConfiguredBaseURLForLinkValidation() throws {
        let root = try makeProjectRoot()
        try writeConfig(
            to: root,
            json: """
            {
              "title": "My Blog",
              "baseURL": "/blog/",
              "theme": "default",
              "outputDir": "docs"
            }
            """
        )
        try FileManager.default.createDirectory(at: root.appendingPathComponent("docs/posts/test"), withIntermediateDirectories: true)
        try "<a href=\"/blog/posts/test/\">test</a>".write(to: root.appendingPathComponent("docs/index.html"), atomically: true, encoding: .utf8)
        try "<h1>Test</h1>".write(to: root.appendingPathComponent("docs/posts/test/index.html"), atomically: true, encoding: .utf8)

        let result = ProjectChecker().check(projectRoot: root)

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.brokenLinks, [])
    }

    func testCheckerReportsTaxonomySlugCollisions() throws {
        let root = try makeProjectRoot()
        try writePost(
            to: root,
            named: "2026-03-08-first.md",
            markdown: """
            ---
            title: First
            date: 2026-03-08T00:00:00Z
            slug: first
            tags: [Swift]
            ---

            Body
            """
        )
        try writePost(
            to: root,
            named: "2026-03-09-second.md",
            markdown: """
            ---
            title: Second
            date: 2026-03-09T00:00:00Z
            slug: second
            tags: [swift!]
            ---

            Body
            """
        )

        let result = ProjectChecker().check(projectRoot: root)

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.brokenLinks, [])
        XCTAssertEqual(result.errors.count, 1)
        if let error = result.errors.first {
            XCTAssertEqual(error, "Taxonomy slug collision for tags 'swift': Swift, swift!")
        }
    }

    func testCheckRejectsRelativeAssetPathInCollectionFrontMatter() throws {
        let root = try makeProjectRoot()
        try writeConfig(to: root, json: """
        {
          "title": "Kris",
          "collections": [
            { "id": "projects", "dir": "content/projects", "route": "/work", "sortBy": "year" }
          ]
        }
        """)
        try writeProject(to: root, named: "wolt.md", markdown: """
        ---
        title: Wolt
        slug: wolt
        year: 2023
        shots: ["assets/foo.png"]
        ---
        body
        """)

        let result = ProjectChecker().check(projectRoot: root)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("relative asset path") }, "errors: \(result.errors)")
    }

    func testCheckRejectsMissingAssetFileInCollection() throws {
        let root = try makeProjectRoot()
        try writeConfig(to: root, json: """
        {
          "title": "Kris",
          "collections": [
            { "id": "projects", "dir": "content/projects", "route": "/work", "sortBy": "year" }
          ]
        }
        """)
        try writeProject(to: root, named: "wolt.md", markdown: """
        ---
        title: Wolt
        slug: wolt
        year: 2023
        shots: ["/assets/missing.png"]
        ---
        body
        """)

        let result = ProjectChecker().check(projectRoot: root)
        XCTAssertTrue(result.errors.contains { $0.contains("missing.png") }, "errors: \(result.errors)")
    }

    func testCheckAllowsFullyQualifiedAssetURLInCollection() throws {
        let root = try makeProjectRoot()
        try writeConfig(to: root, json: """
        {
          "title": "Kris",
          "collections": [
            { "id": "projects", "dir": "content/projects", "route": "/work", "sortBy": "year" }
          ]
        }
        """)
        try writeProject(to: root, named: "wolt.md", markdown: """
        ---
        title: Wolt
        slug: wolt
        year: 2023
        shots: ["https://cdn.example.com/foo.png"]
        ---
        body
        """)

        let result = ProjectChecker().check(projectRoot: root)
        XCTAssertFalse(result.errors.contains { $0.contains("foo.png") }, "errors: \(result.errors)")
    }

    func testCheckResolvesAssetUnderStaticDirectory() throws {
        let root = try makeProjectRoot()
        try writeConfig(to: root, json: """
        {
          "title": "Kris",
          "collections": [
            { "id": "projects", "dir": "content/projects", "route": "/work", "sortBy": "year" }
          ]
        }
        """)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("static/assets/shots"), withIntermediateDirectories: true)
        try Data().write(to: root.appendingPathComponent("static/assets/shots/wolt.png"))
        try writeProject(to: root, named: "wolt.md", markdown: """
        ---
        title: Wolt
        slug: wolt
        year: 2023
        shots: ["/assets/shots/wolt.png"]
        ---
        body
        """)

        let result = ProjectChecker().check(projectRoot: root)
        XCTAssertFalse(result.errors.contains { $0.contains("wolt.png") }, "errors: \(result.errors)")
    }

    private func writeProject(to root: URL, named fileName: String, markdown: String) throws {
        let dir = root.appendingPathComponent("content/projects")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try markdown.write(to: dir.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
    }

    private func makeProjectRoot() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("content/posts"), withIntermediateDirectories: true)
        return root
    }

    private func writePost(to root: URL, named fileName: String, markdown: String) throws {
        try markdown.write(to: root.appendingPathComponent("content/posts/\(fileName)"), atomically: true, encoding: .utf8)
    }

    private func writeConfig(to root: URL, json: String) throws {
        try json.write(to: root.appendingPathComponent("blog.config.json"), atomically: true, encoding: .utf8)
    }
}
