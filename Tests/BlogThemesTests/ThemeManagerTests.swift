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

    func testInjectHeadAssetsIncludesMermaidRuntimeForQuietTheme() {
        let input = "<html><head></head><body></body></html>"
        let output = ThemeManager().injectHeadAssets(into: input, theme: "quiet")

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

    func testInjectHeadAssetsIncludesCodeCopyScriptForBothThemes() {
        let input = "<html><head></head><body></body></html>"
        let defaultOutput = ThemeManager().injectHeadAssets(into: input)
        let quietOutput = ThemeManager().injectHeadAssets(into: input, theme: "quiet")

        XCTAssertTrue(defaultOutput.contains("/assets/js/code-copy.js"), "default theme should include code-copy.js")
        XCTAssertTrue(defaultOutput.contains("/assets/css/code-copy.css"), "default theme should include code-copy.css")
        XCTAssertTrue(quietOutput.contains("/assets/js/code-copy.js"), "quiet theme should include code-copy.js")
    }

    func testInjectHeadAssetsSkipsKatexCSSWhenNoMath() {
        let input = "<html><head></head><body></body></html>"
        let output = ThemeManager().injectHeadAssets(into: input)

        XCTAssertFalse(output.contains("katex.min.css"))
    }

    func testInjectHeadAssetsIncludesKatexCSSWhenHasMath() {
        let input = "<html><head></head><body></body></html>"
        let defaultOutput = ThemeManager().injectHeadAssets(into: input, hasMath: true)
        let quietOutput = ThemeManager().injectHeadAssets(into: input, theme: "quiet", hasMath: true)

        XCTAssertTrue(defaultOutput.contains("/assets/css/katex.min.css"))
        XCTAssertTrue(quietOutput.contains("/assets/css/katex.min.css"))
    }

    func testInjectHeadAssetsKatexCSSRespectsBaseURLPrefix() {
        let input = "<html><head></head><body></body></html>"
        let output = ThemeManager().injectHeadAssets(into: input, baseURL: "https://example.com/blog/", hasMath: true)

        XCTAssertTrue(output.contains("href=\"/blog/assets/css/katex.min.css\""))
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
