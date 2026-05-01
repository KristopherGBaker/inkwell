import Foundation
import XCTest
@testable import BlogCore

final class AssetURLRewriterTests: XCTestCase {
    func testPrefixesRelativeSrcAndHref() {
        let html = #"""
        <video><source src="cover.mp4"></video>
        <a href="related/">related</a>
        """#
        let result = AssetURLRewriter.rewriteRelativeURLs(in: html, base: "/posts/foo/")
        XCTAssertTrue(result.contains(#"src="/posts/foo/cover.mp4""#))
        XCTAssertTrue(result.contains(#"href="/posts/foo/related/""#))
    }

    func testLeavesAbsoluteAndExternalURLsAlone() {
        let html = ##"""
        <a href="/about/">about</a>
        <a href="https://example.com">ext</a>
        <a href="#anchor">anchor</a>
        <a href="mailto:hi@example.com">mail</a>
        <img src="data:image/png;base64,abcd">
        """##
        let result = AssetURLRewriter.rewriteRelativeURLs(in: html, base: "/posts/foo/")
        XCTAssertTrue(result.contains(##"href="/about/""##))
        XCTAssertTrue(result.contains(##"href="https://example.com""##))
        XCTAssertTrue(result.contains(##"href="#anchor""##))
        XCTAssertTrue(result.contains(##"href="mailto:hi@example.com""##))
        XCTAssertTrue(result.contains(##"src="data:image/png;base64,abcd""##))
    }

    func testHandlesPosterAttribute() {
        let html = #"<video poster="thumb.jpg"></video>"#
        let result = AssetURLRewriter.rewriteRelativeURLs(in: html, base: "/posts/foo/")
        XCTAssertTrue(result.contains(#"poster="/posts/foo/thumb.jpg""#))
    }

    func testIdempotent() {
        let html = #"<img src="cover.jpg">"#
        let once = AssetURLRewriter.rewriteRelativeURLs(in: html, base: "/posts/foo/")
        let twice = AssetURLRewriter.rewriteRelativeURLs(in: once, base: "/posts/foo/")
        XCTAssertEqual(once, twice)
    }
}
