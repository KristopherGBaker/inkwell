import Foundation
import XCTest
@testable import BlogCore

final class BuildPipelineIntegrationTests: XCTestCase {
    func testBuildWritesPostAndIndexPages() throws {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: temp.appendingPathComponent("content/posts"), withIntermediateDirectories: true)

        let post = """
        ---
        title: Hello World
        date: 2026-03-05T00:00:00Z
        slug: hello-world
        tags: [swift, logs]
        categories: [engineering]
        ---

        Test post body
        """
        try post.write(to: temp.appendingPathComponent("content/posts/2026-03-05-hello-world.md"), atomically: true, encoding: .utf8)

        let report = try BuildPipeline().run(in: temp)
        XCTAssertEqual(report.errors.count, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/index.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/posts/hello-world/index.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/tags/swift/index.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/categories/engineering/index.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/sitemap.xml").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/robots.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/rss.xml").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/search-index.json").path))

        let indexHTML = try String(contentsOf: temp.appendingPathComponent("docs/index.html"))
        XCTAssertTrue(indexHTML.contains("/posts/hello-world/"))
        XCTAssertTrue(indexHTML.contains("id=\"search-input\""))

        let searchIndexJSON = try String(contentsOf: temp.appendingPathComponent("docs/search-index.json"))
        XCTAssertTrue(searchIndexJSON.contains("\"slug\" : \"hello-world\""))
    }

    func testBuildCreatesSecondPageWhenPostCountExceedsPageSize() throws {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: temp.appendingPathComponent("content/posts"), withIntermediateDirectories: true)

        for day in 1...7 {
            let date = String(format: "2026-03-%02d", day)
            let post = """
            ---
            title: Post \(day)
            date: \(date)T00:00:00Z
            slug: post-\(day)
            ---

            Body
            """
            let fileName = "\(date)-post-\(day).md"
            try post.write(to: temp.appendingPathComponent("content/posts/\(fileName)"), atomically: true, encoding: .utf8)
        }

        _ = try BuildPipeline().run(in: temp)
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/page/2/index.html").path))
    }
}
