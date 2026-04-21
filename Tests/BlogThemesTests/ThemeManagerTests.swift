import Foundation
import XCTest
@testable import BlogThemes

final class ThemeManagerTests: XCTestCase {
    func testSelectingThemeUpdatesConfig() throws {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root.appendingPathComponent("themes/default"), withIntermediateDirectories: true)
        try "{\"title\":\"Test\",\"theme\":\"other\"}".write(to: root.appendingPathComponent("blog.config.json"), atomically: true, encoding: .utf8)

        try ThemeManager().useTheme("default", in: root)

        let data = try Data(contentsOf: root.appendingPathComponent("blog.config.json"))
        let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(payload?["theme"] as? String, "default")
    }

    func testInjectHeadAssetsIncludesMermaidRuntime() {
        let input = "<html><head></head><body></body></html>"
        let output = ThemeManager().injectHeadAssets(into: input)

        XCTAssertTrue(output.contains("mermaid.esm.min.mjs"))
        XCTAssertTrue(output.contains("querySelector: \".mermaid\""))
    }

    func testInjectHeadAssetsPrefixesThemeAssetsForSubpathBaseURL() {
        let input = "<html><head></head><body></body></html>"
        let output = ThemeManager().injectHeadAssets(into: input, baseURL: "https://example.com/blog/")

        XCTAssertTrue(output.contains("href=\"/blog/assets/css/tailwind.css\""))
        XCTAssertTrue(output.contains("href=\"/blog/assets/css/prism.css\""))
        XCTAssertTrue(output.contains("src=\"/blog/assets/js/search.js\""))
        XCTAssertTrue(output.contains("src=\"/blog/assets/js/prism.js\""))
    }

    func testInjectHeadAssetsAppendsExtraHeadBeforeClosingHead() {
        let input = "<html><head></head><body></body></html>"
        let extra = "<link rel=\"icon\" href=\"/favicon.ico\">"
        let output = ThemeManager().injectHeadAssets(into: input, extraHead: extra)

        XCTAssertTrue(output.contains(extra))
        let extraIndex = output.range(of: extra)?.lowerBound
        let closingIndex = output.range(of: "</head>")?.lowerBound
        XCTAssertNotNil(extraIndex)
        XCTAssertNotNil(closingIndex)
        if let extraIndex, let closingIndex {
            XCTAssertLessThan(extraIndex, closingIndex)
        }
    }
}
