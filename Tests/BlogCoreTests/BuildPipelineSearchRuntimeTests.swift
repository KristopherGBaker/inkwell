import Foundation
import XCTest
@testable import BlogCore

final class BuildPipelineSearchRuntimeTests: XCTestCase {
    func testBuiltSearchRuntimeResolvesSubpathURLsFromScriptLocation() throws {
        let temp = try makeTempBlogProject(extraDirectories: ["themes/default/assets/js"])

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
        title: Search Runtime
        date: 2026-03-08T00:00:00Z
        slug: search-runtime
        ---

        Body
        """
        try post.write(to: temp.appendingPathComponent("content/posts/2026-03-08-search-runtime.md"), atomically: true, encoding: .utf8)

        let runtimeSource = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("themes/default/assets/js/search.js")
        try FileManager.default.copyItem(at: runtimeSource, to: temp.appendingPathComponent("themes/default/assets/js/search.js"))

        _ = try BuildPipeline().run(in: temp)

        let searchRuntime = try String(contentsOf: temp.appendingPathComponent("public/assets/js/search.js"))
        XCTAssertTrue(searchRuntime.contains("document.currentScript"))
        XCTAssertTrue(searchRuntime.contains("/search-index.json"))
        XCTAssertTrue(searchRuntime.contains("/posts/"))
        XCTAssertFalse(searchRuntime.contains("fetch('/search-index.json'"))
        XCTAssertFalse(searchRuntime.contains("href=\"/posts/${post.slug}/\""))
    }
}
