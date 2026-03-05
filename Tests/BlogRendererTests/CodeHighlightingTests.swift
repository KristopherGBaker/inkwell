import XCTest
@testable import BlogRenderer

final class CodeHighlightingTests: XCTestCase {
    func testCodeFenceIncludesLanguageClass() throws {
        let html = try GFMEngine().render("```swift\nprint(\"hi\")\n```")
        XCTAssertTrue(html.contains("class=\"language-swift\""))
    }
}
