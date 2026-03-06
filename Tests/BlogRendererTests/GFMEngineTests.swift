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
