import Foundation
import XCTest
@testable import BlogCore

final class PageContextBuilderTests: XCTestCase {
    func testBuildPlansEmitsArchiveRouteWithPublishedPostsNewestFirstAndDraftsExcluded() throws {
        let plans = PageContextBuilder().buildPlans(
            posts: [
                makePost(title: "Old Post", date: "2026-03-01T00:00:00Z", slug: "old-post"),
                makePost(title: "New Post", date: "2026-03-05T00:00:00Z", slug: "new-post"),
                makePost(title: "Draft Post", date: "2026-03-07T00:00:00Z", slug: "draft-post", draft: true)
            ],
            renderedContent: [:]
        )

        let archive = try XCTUnwrap(plans.first(where: { $0.route == "/archive/" }))
        let archivePosts = try XCTUnwrap(archive.context["posts"] as? [[String: Any]])
        XCTAssertEqual(archivePosts.map { $0["slug"] as? String }, ["new-post", "old-post"])

        XCTAssertNil(plans.first(where: { $0.route == "/posts/draft-post/" }))
        XCTAssertEqual(plans.first(where: { $0.route == "/" })?.template, "layouts/landing")
    }

    func testLandingLinksToArchive() throws {
        let plans = PageContextBuilder().buildPlans(
            posts: [makePost(title: "One", date: "2026-03-05T00:00:00Z", slug: "one")],
            renderedContent: [:]
        )
        let landing = try XCTUnwrap(plans.first(where: { $0.route == "/" }))
        let links = try XCTUnwrap(landing.context["links"] as? [String: String])
        XCTAssertEqual(links["archive"], "/archive/")
    }

    func testPostPlanCarriesPageMetadata() throws {
        let plans = PageContextBuilder().buildPlans(
            posts: [makePost(title: "Hello", date: "2026-03-05T00:00:00Z", slug: "hello", summary: "Greetings.")],
            renderedContent: ["hello": "<p>Hi there.</p>"]
        )
        let post = try XCTUnwrap(plans.first(where: { $0.route == "/posts/hello/" }))
        XCTAssertEqual(post.template, "layouts/post")
        let pageContext = try XCTUnwrap(post.context["page"] as? [String: Any])
        XCTAssertEqual(pageContext["title"] as? String, "Hello")
        XCTAssertEqual(pageContext["content"] as? String, "<p>Hi there.</p>")
    }

    private func makePost(title: String, date: String, slug: String, summary: String = "Notes", draft: Bool = false) -> PostDocument {
        PostDocument(
            frontMatter: PostFrontMatter(
                title: title,
                date: date,
                slug: slug,
                summary: summary,
                draft: draft
            ),
            body: "Body for \(title)",
            sourcePath: URL(fileURLWithPath: "/tmp/\(slug).md")
        )
    }
}
