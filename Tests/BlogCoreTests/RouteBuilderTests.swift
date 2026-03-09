import Foundation
import XCTest
@testable import BlogCore

final class RouteBuilderTests: XCTestCase {
    func testBuildPagesEmitsArchiveRouteWithPublishedPostsNewestFirstAndLinksFromHomeHeader() throws {
        let pages = RouteBuilder().buildPages(
            posts: [
                makePost(title: "Old Post", date: "2026-03-01T00:00:00Z", slug: "old-post"),
                makePost(title: "New Post", date: "2026-03-05T00:00:00Z", slug: "new-post"),
                makePost(title: "Draft Post", date: "2026-03-07T00:00:00Z", slug: "draft-post", draft: true)
            ],
            renderedContent: [:]
        )

        let homePage = try XCTUnwrap(pages.first(where: { $0.route == "/" }))
        XCTAssertTrue(homePage.html.contains("href=\"/archive/\""))

        let archivePage = try XCTUnwrap(pages.first(where: { $0.route == "/archive/" }))
        XCTAssertLessThan(
            try XCTUnwrap(archivePage.html.range(of: "/posts/new-post/")?.lowerBound),
            try XCTUnwrap(archivePage.html.range(of: "/posts/old-post/")?.lowerBound)
        )
        XCTAssertFalse(archivePage.html.contains("/posts/draft-post/"))
    }

    private func makePost(title: String, date: String, slug: String, draft: Bool = false) -> PostDocument {
        PostDocument(
            frontMatter: PostFrontMatter(
                title: title,
                date: date,
                slug: slug,
                summary: "Summary for \(title)",
                draft: draft
            ),
            body: "Body for \(title)",
            sourcePath: URL(fileURLWithPath: "/tmp/\(slug).md")
        )
    }
}
