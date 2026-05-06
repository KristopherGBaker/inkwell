import Foundation
import XCTest
@testable import BlogCore

final class AnalyticsContextTests: XCTestCase {
    func testBuildModeUsesProdBlock() throws {
        let config = SiteConfig(
            title: "Kris",
            analytics: AnalyticsConfig(umami: UmamiConfig(
                scriptUrl: "https://analytics.krisbaker.com/script.js",
                websiteId: "prod-id",
                hostUrl: "https://analytics.krisbaker.com",
                domains: "krisbaker.com",
                respectDoNotTrack: true,
                tag: "site",
                local: UmamiLocalConfig(scriptUrl: "http://localhost:3000/script.js", websiteId: "local-id")
            ))
        )

        let ctx = try XCTUnwrap(PageContextBuilder().analyticsContext(for: config, mode: .build))
        let umami = try XCTUnwrap(ctx["umami"] as? [String: Any])
        XCTAssertEqual(umami["scriptUrl"] as? String, "https://analytics.krisbaker.com/script.js")
        XCTAssertEqual(umami["websiteId"] as? String, "prod-id")
        XCTAssertEqual(umami["hostUrl"] as? String, "https://analytics.krisbaker.com")
        XCTAssertEqual(umami["domains"] as? String, "krisbaker.com")
        XCTAssertEqual(umami["respectDoNotTrack"] as? Bool, true)
        XCTAssertEqual(umami["tag"] as? String, "site")
    }

    func testServeModeUsesLocalBlockWhenPresent() throws {
        let config = SiteConfig(
            title: "Kris",
            analytics: AnalyticsConfig(umami: UmamiConfig(
                scriptUrl: "https://analytics.krisbaker.com/script.js",
                websiteId: "prod-id",
                domains: "krisbaker.com",
                local: UmamiLocalConfig(
                    scriptUrl: "http://localhost:3000/script.js",
                    websiteId: "local-id",
                    hostUrl: "http://localhost:3000",
                    domains: "localhost"
                )
            ))
        )

        let ctx = try XCTUnwrap(PageContextBuilder().analyticsContext(for: config, mode: .serve))
        let umami = try XCTUnwrap(ctx["umami"] as? [String: Any])
        XCTAssertEqual(umami["scriptUrl"] as? String, "http://localhost:3000/script.js")
        XCTAssertEqual(umami["websiteId"] as? String, "local-id")
        XCTAssertEqual(umami["hostUrl"] as? String, "http://localhost:3000")
        XCTAssertEqual(umami["domains"] as? String, "localhost")
        XCTAssertNil(umami["respectDoNotTrack"], "Local block didn't set DNT, so it should be absent")
        XCTAssertNil(umami["tag"])
    }

    func testServeModeWithoutLocalBlockEmitsNothing() {
        let config = SiteConfig(
            title: "Kris",
            analytics: AnalyticsConfig(umami: UmamiConfig(
                scriptUrl: "https://analytics.krisbaker.com/script.js",
                websiteId: "prod-id",
                domains: "krisbaker.com"
            ))
        )

        XCTAssertNil(
            PageContextBuilder().analyticsContext(for: config, mode: .serve),
            "Without a `local` block, serve mode must not surface the prod tag — that's the whole point of the override"
        )
    }

    func testBothModesEmitNothingWhenAnalyticsIsUnset() {
        let config = SiteConfig(title: "Kris")
        XCTAssertNil(PageContextBuilder().analyticsContext(for: config, mode: .build))
        XCTAssertNil(PageContextBuilder().analyticsContext(for: config, mode: .serve))
    }

    func testValuesAreHTMLEscaped() throws {
        let config = SiteConfig(
            title: "Kris",
            analytics: AnalyticsConfig(umami: UmamiConfig(
                scriptUrl: "https://x/s.js?a=1&b=2",
                websiteId: "<id>",
                tag: "a&b"
            ))
        )

        let ctx = try XCTUnwrap(PageContextBuilder().analyticsContext(for: config, mode: .build))
        let umami = try XCTUnwrap(ctx["umami"] as? [String: Any])
        XCTAssertEqual(umami["scriptUrl"] as? String, "https://x/s.js?a=1&amp;b=2")
        XCTAssertEqual(umami["websiteId"] as? String, "&lt;id&gt;")
        XCTAssertEqual(umami["tag"] as? String, "a&amp;b")
    }

    func testFalseyDoNotTrackIsOmittedFromContext() throws {
        let config = SiteConfig(
            title: "Kris",
            analytics: AnalyticsConfig(umami: UmamiConfig(
                scriptUrl: "https://x/s.js",
                websiteId: "id",
                respectDoNotTrack: false
            ))
        )

        let ctx = try XCTUnwrap(PageContextBuilder().analyticsContext(for: config, mode: .build))
        let umami = try XCTUnwrap(ctx["umami"] as? [String: Any])
        XCTAssertNil(
            umami["respectDoNotTrack"],
            "false should be omitted so the template doesn't render data-do-not-track=\"false\""
        )
    }
}
