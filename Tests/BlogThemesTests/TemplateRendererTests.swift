import Foundation
import XCTest
@testable import BlogThemes

final class TemplateRendererTests: XCTestCase {
    func testRendersBundledLandingTemplate() throws {
        let renderer = try TemplateRenderer(theme: "default", projectRoot: nil)
        let html = try renderer.render(template: "layouts/landing", context: defaultContext(
            site: ["title": "Field Notes", "description": "A blog", "tagline": "Tagline.", "searchEnabled": true, "baseURL": "/"],
            page: ["title": "Field Notes", "description": "A blog", "canonicalURL": "https://example.com/", "twitterCard": "summary"],
            extras: ["posts": [], "pagination": ["currentPage": 1, "totalPages": 1, "items": []], "links": ["home": "/", "archive": "/archive/"]]
        ))
        XCTAssertTrue(html.contains("<title>Field Notes</title>"))
        XCTAssertTrue(html.contains("href=\"/archive/\""))
        XCTAssertTrue(html.contains("id=\"search-input\""))
    }

    func testProjectTemplatesOverrideBundledOnes() throws {
        let projectRoot = makeTempDirectory()
        let templatesRoot = projectRoot
            .appendingPathComponent("themes/default/templates")
        try FileManager.default.createDirectory(at: templatesRoot, withIntermediateDirectories: true)
        try "<p>{{ message }}</p>".write(to: templatesRoot.appendingPathComponent("base.html"), atomically: true, encoding: .utf8)

        let renderer = try TemplateRenderer(theme: "default", projectRoot: projectRoot)
        let html = try renderer.render(template: "base", context: ["message": "Hello"])
        XCTAssertEqual(html, "<p>Hello</p>")
    }

    func testEscapeFilterEscapesHTMLEntities() throws {
        let projectRoot = makeTempDirectory()
        let templatesRoot = projectRoot.appendingPathComponent("themes/default/templates")
        try FileManager.default.createDirectory(at: templatesRoot, withIntermediateDirectories: true)
        try "{{ value|escape }}".write(to: templatesRoot.appendingPathComponent("base.html"), atomically: true, encoding: .utf8)

        let renderer = try TemplateRenderer(theme: "default", projectRoot: projectRoot)
        let html = try renderer.render(template: "base", context: ["value": "<\"a&b\">"])
        XCTAssertEqual(html, "&lt;&quot;a&amp;b&quot;&gt;")
    }

    func testRenderFailsWithDescriptiveErrorWhenTemplateMissing() throws {
        let renderer = try TemplateRenderer(theme: "default", projectRoot: nil)
        XCTAssertThrowsError(try renderer.render(template: "layouts/does-not-exist", context: [:]))
    }

    private func defaultContext(site: [String: Any], page: [String: Any], extras: [String: Any]) -> [String: Any] {
        var context: [String: Any] = ["site": site, "page": page]
        for (key, value) in extras {
            context[key] = value
        }
        return context
    }

    private func makeTempDirectory() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
