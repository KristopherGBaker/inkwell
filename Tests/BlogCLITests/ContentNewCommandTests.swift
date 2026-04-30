import Foundation
import XCTest
@testable import BlogCLI

final class ContentNewCommandTests: XCTestCase {
    func testContentNewProjectsCreatesYearStyleScaffoldedFile() throws {
        let root = makeTempProject()
        try writeConfig(root, """
        {
          "title": "Kris",
          "collections": [
            { "id": "projects", "dir": "content/projects", "route": "/work", "sortBy": "year" }
          ]
        }
        """)

        let path = try ContentNewCommand.scaffold(root: root, collectionId: "projects", title: "Wolt Membership")
        XCTAssertEqual(path.lastPathComponent, "wolt-membership.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))

        let content = try String(contentsOf: path)
        XCTAssertTrue(content.contains("title: Wolt Membership"))
        XCTAssertTrue(content.contains("slug: wolt-membership"))
        XCTAssertTrue(content.contains("year:"))
    }

    func testContentNewPostsCreatesDateStyleScaffoldedFile() throws {
        let root = makeTempProject()
        try writeConfig(root, """
        {
          "title": "Kris",
          "collections": [
            { "id": "posts", "dir": "content/posts", "route": "/posts" }
          ]
        }
        """)

        let path = try ContentNewCommand.scaffold(root: root, collectionId: "posts", title: "Hello World")
        XCTAssertTrue(path.lastPathComponent.hasSuffix("-hello-world.md"))
        let content = try String(contentsOf: path)
        XCTAssertTrue(content.contains("title: Hello World"))
        XCTAssertTrue(content.contains("draft: true"))
    }

    func testContentNewRejectsUnknownCollection() throws {
        let root = makeTempProject()
        try writeConfig(root, """
        {
          "title": "Kris",
          "collections": [
            { "id": "posts", "dir": "content/posts", "route": "/posts" }
          ]
        }
        """)
        XCTAssertThrowsError(try ContentNewCommand.scaffold(root: root, collectionId: "nope", title: "x"))
    }

    private func writeConfig(_ root: URL, _ json: String) throws {
        try json.write(to: root.appendingPathComponent("blog.config.json"), atomically: true, encoding: .utf8)
    }

    private func makeTempProject() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
