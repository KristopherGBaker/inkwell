import Foundation
import XCTest
@testable import BlogCore

final class TOCIntegrationTests: XCTestCase {
    func testPostWithThreeOrMoreH2sAutoGetsTOC() throws {
        let temp = try makeTempBlogProject()
        let post = """
        ---
        title: Long Read
        date: 2026-04-12T00:00:00Z
        slug: long-read
        ---

        ## Background

        body

        ## Approach

        body

        ## Outcome

        body
        """
        try post.write(
            to: temp.appendingPathComponent("content/posts/2026-04-12-long-read.md"),
            atomically: true,
            encoding: .utf8
        )

        let report = try BuildPipeline().run(in: temp)
        XCTAssertEqual(report.errors.count, 0)
        let html = try String(contentsOf: temp.appendingPathComponent("docs/posts/long-read/index.html"))
        XCTAssertTrue(html.contains("class=\"toc\""), "expected TOC nav")
        XCTAssertTrue(html.contains("href=\"#background\""))
        XCTAssertTrue(html.contains("href=\"#approach\""))
        XCTAssertTrue(html.contains("href=\"#outcome\""))
        XCTAssertTrue(html.contains("<h2 id=\"background\""), "headings get id attrs")
    }

    func testPostWithFewerH2sDoesNotGetTOC() throws {
        let temp = try makeTempBlogProject()
        let post = """
        ---
        title: Short
        date: 2026-04-12T00:00:00Z
        slug: short
        ---

        ## Only

        body
        """
        try post.write(
            to: temp.appendingPathComponent("content/posts/2026-04-12-short.md"),
            atomically: true,
            encoding: .utf8
        )

        _ = try BuildPipeline().run(in: temp)
        let html = try String(contentsOf: temp.appendingPathComponent("docs/posts/short/index.html"))
        XCTAssertFalse(html.contains("class=\"toc\""), "single-h2 post should not auto-trigger TOC")
        XCTAssertTrue(html.contains("<h2 id=\"only\""), "ID is still attached for anchor links")
    }

    func testFrontMatterTocTrueForcesTOC() throws {
        let temp = try makeTempBlogProject()
        let post = """
        ---
        title: Forced
        date: 2026-04-12T00:00:00Z
        slug: forced
        toc: true
        ---

        ## Only

        body
        """
        try post.write(
            to: temp.appendingPathComponent("content/posts/2026-04-12-forced.md"),
            atomically: true,
            encoding: .utf8
        )

        _ = try BuildPipeline().run(in: temp)
        let html = try String(contentsOf: temp.appendingPathComponent("docs/posts/forced/index.html"))
        XCTAssertTrue(html.contains("class=\"toc\""), "toc:true overrides the auto-trigger threshold")
        XCTAssertTrue(html.contains("href=\"#only\""))
    }

    func testH3HeadingsNestUnderPrecedingH2() throws {
        let temp = try makeTempBlogProject()
        let post = """
        ---
        title: Nested
        date: 2026-04-12T00:00:00Z
        slug: nested
        toc: true
        ---

        ## Section A

        ### Detail one

        ### Detail two

        ## Section B
        """
        try post.write(
            to: temp.appendingPathComponent("content/posts/2026-04-12-nested.md"),
            atomically: true,
            encoding: .utf8
        )

        _ = try BuildPipeline().run(in: temp)
        let html = try String(contentsOf: temp.appendingPathComponent("docs/posts/nested/index.html"))
        // h3 entries should sit inside the h2's children sublist.
        XCTAssertTrue(html.contains("<ol class=\"toc-sublist\">"), "h3s should render inside a nested sublist")
        XCTAssertTrue(html.contains("href=\"#detail-one\""))
        XCTAssertTrue(html.contains("href=\"#detail-two\""))
    }
}
