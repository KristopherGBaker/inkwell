import XCTest
@testable import BlogRenderer

final class MathEngineTests: XCTestCase {
    // MARK: - Detection (no Node required)

    func testInlineMathExtraction() {
        let result = MathEngine().extract(markdown: "Einstein wrote $E = mc^2$ on a chalkboard.")
        XCTAssertEqual(result.runs.count, 1)
        XCTAssertEqual(result.runs.first?.source, "E = mc^2")
        XCTAssertFalse(result.runs.first?.isBlock ?? true)
        XCTAssertTrue(result.hasMath)
        XCTAssertFalse(result.markdown.contains("$E = mc^2$"))
    }

    func testBlockMathExtractionFromFencedDollarPair() {
        let markdown = """
        Here is a block:

        $$
        a^2 + b^2 = c^2
        $$

        Done.
        """
        let result = MathEngine().extract(markdown: markdown)
        XCTAssertEqual(result.runs.count, 1)
        XCTAssertEqual(result.runs.first?.source, "a^2 + b^2 = c^2")
        XCTAssertTrue(result.runs.first?.isBlock ?? false)
        XCTAssertFalse(result.markdown.contains("$$"))
    }

    func testCurrencyAmountsAreNotMath() {
        let result = MathEngine().extract(markdown: "Pay $5 today and $10 tomorrow.")
        XCTAssertEqual(result.runs.count, 0)
        XCTAssertFalse(result.hasMath)
        XCTAssertEqual(result.markdown, "Pay $5 today and $10 tomorrow.")
    }

    func testInlineCodeSpansAreNotProcessed() {
        let result = MathEngine().extract(markdown: "Use `$pricing$` config and read $E = mc^2$ aloud.")
        XCTAssertEqual(result.runs.count, 1)
        XCTAssertEqual(result.runs.first?.source, "E = mc^2")
        XCTAssertTrue(result.markdown.contains("`$pricing$`"))
    }

    func testFencedCodeBlocksAreNotProcessed() {
        let markdown = """
        Top text.

        ```latex
        $E = mc^2$
        ```

        Bottom text.
        """
        let result = MathEngine().extract(markdown: markdown)
        XCTAssertEqual(result.runs.count, 0)
        XCTAssertTrue(result.markdown.contains("$E = mc^2$"))
    }

    func testWhitespaceAdjacentInlineDoesNotMatch() {
        // "$ foo$" and "$foo $" should not match — non-whitespace adjacency required.
        let result = MathEngine().extract(markdown: "Edge $ foo$ and $bar $ are not math.")
        XCTAssertEqual(result.runs.count, 0)
    }

    func testEmptyDocumentHasNoMath() {
        XCTAssertFalse(MathEngine().extract(markdown: "").hasMath)
        XCTAssertFalse(MathEngine().extract(markdown: "Just words.").hasMath)
    }

    func testMultipleInlineMathOnSameLine() {
        let result = MathEngine().extract(markdown: "Compare $a+b$ to $c-d$ here.")
        XCTAssertEqual(result.runs.count, 2)
        XCTAssertEqual(result.runs[0].source, "a+b")
        XCTAssertEqual(result.runs[1].source, "c-d")
    }

    // MARK: - Restitching

    func testRestitchReplacesPlaceholdersWithRenderedHTML() {
        let runs = [
            MathEngine.MathRun(id: 0, source: "x+y", isBlock: false),
            MathEngine.MathRun(id: 1, source: "z=0", isBlock: true)
        ]
        let html = """
        <p>Inline: \(MathEngine().placeholder(for: runs[0])) here.</p>
        <p>\(MathEngine().placeholder(for: runs[1]))</p>
        """
        let renderedRuns = [
            0: "<span class=\"katex\">x+y</span>",
            1: "<span class=\"katex-display\">z=0</span>"
        ]
        let stitched = MathEngine().restitch(html: html, runs: runs, renderedHTML: renderedRuns)
        XCTAssertTrue(stitched.contains("<span class=\"math math-inline\"><span class=\"katex\">x+y</span></span>"))
        XCTAssertTrue(stitched.contains("<div class=\"math math-block\"><span class=\"katex-display\">z=0</span></div>"))
        XCTAssertFalse(stitched.contains("inkwell-math"))
    }

    func testRestitchWithMissingRenderFallsBackToRawSource() {
        let run = MathEngine.MathRun(id: 0, source: "x+y", isBlock: false)
        let html = "<p>\(MathEngine().placeholder(for: run))</p>"
        let stitched = MathEngine().restitch(html: html, runs: [run], renderedHTML: [:])
        XCTAssertTrue(stitched.contains("x+y"))
        XCTAssertFalse(stitched.contains("inkwell-math"))
    }
}
