import XCTest
@testable import BlogCore

final class HeadingExtractorTests: XCTestCase {
    func testExtractsH2AndH3WithSlugifiedAnchors() {
        let html = """
        <h2>First section</h2>
        <p>body</p>
        <h3>Subsection</h3>
        <h2>Second section</h2>
        """
        let result = HeadingExtractor.extract(html: html)
        XCTAssertEqual(result.headings.map(\.level), [2, 3, 2])
        XCTAssertEqual(result.headings.map(\.text), ["First section", "Subsection", "Second section"])
        XCTAssertEqual(result.headings.map(\.anchor), ["first-section", "subsection", "second-section"])
    }

    func testRewritesHTMLToIncludeIDsOnHeadings() {
        let html = "<h2>Hello world</h2><p>x</p><h3>Sub</h3>"
        let result = HeadingExtractor.extract(html: html)
        XCTAssertTrue(result.html.contains("<h2 id=\"hello-world\""), "got: \(result.html)")
        XCTAssertTrue(result.html.contains("<h3 id=\"sub\""))
    }

    func testDeduplicatesCollidingAnchors() {
        let html = "<h2>Notes</h2><h2>Notes</h2><h2>Notes</h2>"
        let result = HeadingExtractor.extract(html: html)
        XCTAssertEqual(result.headings.map(\.anchor), ["notes", "notes-2", "notes-3"])
    }

    func testIgnoresH1AndDeeperHeadings() {
        let html = "<h1>Title</h1><h2>One</h2><h4>Skip</h4><h5>Skip</h5>"
        let result = HeadingExtractor.extract(html: html)
        XCTAssertEqual(result.headings.map(\.text), ["One"])
    }

    func testStripsInlineTagsFromHeadingText() {
        let html = "<h2>Hello <em>brave</em> <code>world</code></h2>"
        let result = HeadingExtractor.extract(html: html)
        XCTAssertEqual(result.headings.first?.text, "Hello brave world")
        XCTAssertEqual(result.headings.first?.anchor, "hello-brave-world")
    }

    func testPreservesExistingIDOnHeading() {
        let html = "<h2 id=\"custom\">Heading</h2>"
        let result = HeadingExtractor.extract(html: html)
        XCTAssertEqual(result.headings.first?.anchor, "custom")
        XCTAssertTrue(result.html.contains("id=\"custom\""))
    }

    func testHandlesEmptyOrHeadingFreeContent() {
        XCTAssertEqual(HeadingExtractor.extract(html: "").headings.count, 0)
        XCTAssertEqual(HeadingExtractor.extract(html: "<p>just paragraphs</p>").headings.count, 0)
    }
}
