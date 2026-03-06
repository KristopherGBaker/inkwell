import Foundation
import XCTest
@testable import BlogRenderer

final class GFMEngineTests: XCTestCase {
    func testGFMFeaturesRenderAsExpectedHTML() throws {
        let markdown = try fixture("markdown/gfm-sample.md")
        let expected = try fixture("html/gfm-sample.html")
        let actual = try GFMEngine().render(markdown)
        XCTAssertEqual(normalize(actual), normalize(expected))
    }

    func testAutolinkRendersToAnchorTag() throws {
        let actual = try GFMEngine().render("<https://example.com>")
        XCTAssertTrue(actual.contains("<a href=\"https://example.com\""))
    }

    func testGFMAlertBlockRendersAsAside() throws {
        let markdown = """
        > [!NOTE]
        > This is important.
        """

        let actual = try GFMEngine().render(markdown)
        XCTAssertTrue(actual.contains("<aside class=\"alert alert-note\""))
        XCTAssertTrue(actual.contains("This is important."))
    }

    func testMermaidFenceRendersMermaidBlock() throws {
        let markdown = """
        ```mermaid
        graph TD
          A[Start] --> B[Done]
        ```
        """

        let actual = try GFMEngine().render(markdown)
        XCTAssertTrue(actual.contains("<pre class=\"mermaid\">"))
        XCTAssertTrue(actual.contains("graph TD"))
        XCTAssertFalse(actual.contains("language-mermaid"))
    }

    private func fixture(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent("Fixtures/\(path)")
        return try String(contentsOf: url)
    }

    private func normalize(_ value: String) -> String {
        value.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: " ", with: "")
    }
}
