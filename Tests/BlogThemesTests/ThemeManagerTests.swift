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
}
