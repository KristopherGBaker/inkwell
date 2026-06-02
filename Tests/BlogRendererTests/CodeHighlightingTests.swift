import XCTest
@testable import BlogRenderer

final class CodeHighlightingTests: XCTestCase {
    func testCodeFenceIncludesHighlightMarkup() throws {
        let html = try GFMEngine().render("```swift\nprint(\"hi\")\n```")
        XCTAssertTrue(html.contains("class=\"language-swift\"") || html.contains("class=\"shiki"))
    }

    func testCodeFenceUsesConfiguredHighlightScriptWhenAvailable() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodeHighlightingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let script = directory.appendingPathComponent("highlight-code.mjs")
        try """
        process.stdout.write('<pre class="shiki"><code><span>highlighted</span></code></pre>')
        """.write(to: script, atomically: true, encoding: .utf8)

        let html = try GFMEngine(highlightScriptURL: script).render("```swift\nprint(\"hi\")\n```")
        XCTAssertTrue(html.contains("class=\"shiki\""))
        XCTAssertTrue(html.contains("highlighted"))
        XCTAssertFalse(html.contains("language-swift"))
    }
}
