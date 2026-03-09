import Foundation
import XCTest
@testable import BlogCore

final class BuildPipelineOutputTests: XCTestCase {
    func testBuildPrefixesInSiteLinksForSubpathBaseURL() throws {
        let temp = try makeTempBlogProject()

        let config = """
        {
          "title": "Field Notes",
          "baseURL": "https://example.com/blog/",
          "theme": "default",
          "outputDir": "public"
        }
        """
        try config.write(to: temp.appendingPathComponent("blog.config.json"), atomically: true, encoding: .utf8)

        let post = """
        ---
        title: Base Path Ready
        date: 2026-03-08T00:00:00Z
        slug: base-path-ready
        coverImage: '  /images/cover.jpg  '
        tags: [swift]
        categories: [engineering]
        ---

        Body
        """
        try post.write(to: temp.appendingPathComponent("content/posts/2026-03-08-base-path-ready.md"), atomically: true, encoding: .utf8)

        let report = try BuildPipeline().run(in: temp)
        XCTAssertEqual(report.outputDirectory.lastPathComponent, "public")

        let indexHTML = try String(contentsOf: temp.appendingPathComponent("public/index.html"))
        XCTAssertTrue(indexHTML.contains("href=\"/blog/archive/\""))
        XCTAssertTrue(indexHTML.contains("href=\"/blog/posts/base-path-ready/\""))
        XCTAssertTrue(indexHTML.contains("href=\"/blog/assets/css/tailwind.css\""))
        XCTAssertTrue(indexHTML.contains("href=\"/blog/assets/css/prism.css\""))
        XCTAssertTrue(indexHTML.contains("src=\"/blog/assets/js/search.js\""))
        XCTAssertTrue(indexHTML.contains("src=\"/blog/assets/js/prism.js\""))

        let archiveHTML = try String(contentsOf: temp.appendingPathComponent("public/archive/index.html"))
        XCTAssertTrue(archiveHTML.contains("href=\"/blog/\""))
        XCTAssertTrue(archiveHTML.contains("href=\"/blog/posts/base-path-ready/\""))

        let postHTML = try String(contentsOf: temp.appendingPathComponent("public/posts/base-path-ready/index.html"))
        XCTAssertTrue(postHTML.contains("href=\"/blog/\""))
        XCTAssertTrue(postHTML.contains("src=\"/blog/images/cover.jpg\""))
        XCTAssertTrue(postHTML.contains("href=\"/blog/tags/swift/\""))
        XCTAssertTrue(postHTML.contains("href=\"/blog/categories/engineering/\""))

        let tagHTML = try String(contentsOf: temp.appendingPathComponent("public/tags/swift/index.html"))
        XCTAssertTrue(tagHTML.contains("href=\"/blog/\""))
        XCTAssertTrue(tagHTML.contains("href=\"/blog/posts/base-path-ready/\""))

        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("public/rss.xml").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/index.html").path))
    }

    func testBuildCopiesProjectPublicAssetsIntoOutputDirectory() throws {
        let temp = try makeTempBlogProject(extraDirectories: ["public/images"])

        let config = """
        {
          "title": "Field Notes",
          "baseURL": "/",
          "theme": "default",
          "outputDir": "site"
        }
        """
        try config.write(to: temp.appendingPathComponent("blog.config.json"), atomically: true, encoding: .utf8)
        try Data("cover-image".utf8).write(to: temp.appendingPathComponent("public/images/cover.jpg"))

        let post = """
        ---
        title: Public Asset
        date: 2026-03-08T00:00:00Z
        slug: public-asset
        coverImage: /images/cover.jpg
        ---

        Body
        """
        try post.write(to: temp.appendingPathComponent("content/posts/2026-03-08-public-asset.md"), atomically: true, encoding: .utf8)

        _ = try BuildPipeline().run(in: temp)

        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("site/images/cover.jpg").path))
        let copiedData = try Data(contentsOf: temp.appendingPathComponent("site/images/cover.jpg"))
        let copiedString = try XCTUnwrap(String(bytes: copiedData, encoding: .utf8))
        XCTAssertEqual(copiedString, "cover-image")
    }

    func testBuildDoesNotRecopyNestedPublicOutputOnRepeatedBuilds() throws {
        let temp = try makeTempBlogProject(extraDirectories: ["public/images"])

        let config = """
        {
          "title": "Field Notes",
          "baseURL": "/",
          "theme": "default",
          "outputDir": "public/site"
        }
        """
        try config.write(to: temp.appendingPathComponent("blog.config.json"), atomically: true, encoding: .utf8)
        try Data("cover-image".utf8).write(to: temp.appendingPathComponent("public/images/cover.jpg"))

        let post = """
        ---
        title: Nested Public Output
        date: 2026-03-08T00:00:00Z
        slug: nested-public-output
        coverImage: /images/cover.jpg
        ---

        Body
        """
        try post.write(to: temp.appendingPathComponent("content/posts/2026-03-08-nested-public-output.md"), atomically: true, encoding: .utf8)

        let pipeline = BuildPipeline()
        _ = try pipeline.run(in: temp)
        _ = try pipeline.run(in: temp)

        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("public/site/index.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("public/site/images/cover.jpg").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temp.appendingPathComponent("public/site/site/index.html").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temp.appendingPathComponent("public/site/site/images/cover.jpg").path))
    }
}
