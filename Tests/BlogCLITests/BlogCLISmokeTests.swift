import Foundation
import XCTest
@testable import BlogCLI

final class BlogCLISmokeTests: XCTestCase {
    func testCLITypeLoads() {
        XCTAssertNotNil(BlogCommand.configuration)
    }

    func testSlugifyGeneratesExpectedSlug() {
        XCTAssertEqual(slugify("Hello World"), "hello-world")
    }

    func testInitCreatesBaseFiles() throws {
        let fm = FileManager.default
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)
        let old = fm.currentDirectoryPath
        _ = fm.changeCurrentDirectoryPath(temp.path)
        defer { _ = fm.changeCurrentDirectoryPath(old) }

        var command = InitCommand()
        try command.run()

        XCTAssertTrue(fm.fileExists(atPath: temp.appendingPathComponent("blog.config.json").path))
        XCTAssertTrue(fm.fileExists(atPath: temp.appendingPathComponent("content/posts").path))
        XCTAssertTrue(fm.fileExists(atPath: temp.appendingPathComponent("themes/default/assets/css/tailwind.css").path))
        XCTAssertTrue(fm.fileExists(atPath: temp.appendingPathComponent("themes/default/assets/js/search.js").path))

        let searchRuntime = try String(contentsOf: temp.appendingPathComponent("themes/default/assets/js/search.js"))
        XCTAssertTrue(searchRuntime.contains("document.currentScript"))
        XCTAssertTrue(searchRuntime.contains("/search-index.json"))
        XCTAssertTrue(searchRuntime.contains("/posts/"))
        XCTAssertFalse(searchRuntime.contains("fetch('/search-index.json'"))
        XCTAssertFalse(searchRuntime.contains("href=\"/posts/${post.slug}/\""))
    }

    func testInitScaffoldsGitignoreWithInkwellCache() throws {
        let fm = FileManager.default
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)
        let old = fm.currentDirectoryPath
        _ = fm.changeCurrentDirectoryPath(temp.path)
        defer { _ = fm.changeCurrentDirectoryPath(old) }

        var command = InitCommand()
        try command.run()

        let gitignorePath = temp.appendingPathComponent(".gitignore")
        XCTAssertTrue(fm.fileExists(atPath: gitignorePath.path))
        let contents = try String(contentsOf: gitignorePath)
        XCTAssertTrue(contents.contains(".inkwell-cache/"), ".gitignore should include the build cache directory")
    }

    func testPostPublishFlipsDraftToFalseBySlug() throws {
        let fm = FileManager.default
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: temp.appendingPathComponent("content/posts"), withIntermediateDirectories: true)
        let postPath = temp.appendingPathComponent("content/posts/2026-03-06-hello.md")
        let markdown = """
        ---
        title: Hello
        date: 2026-03-06T00:00:00Z
        slug: hello
        draft: true
        ---

        body
        """
        try markdown.write(to: postPath, atomically: true, encoding: .utf8)

        let old = fm.currentDirectoryPath
        _ = fm.changeCurrentDirectoryPath(temp.path)
        defer { _ = fm.changeCurrentDirectoryPath(old) }

        var command = PostPublishCommand()
        command.slug = "hello"
        try command.run()

        let updated = try String(contentsOf: postPath)
        XCTAssertTrue(updated.contains("draft: false"))
        XCTAssertFalse(updated.contains("draft: true"))
    }
}
