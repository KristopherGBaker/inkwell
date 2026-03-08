import XCTest
@testable import BlogThemes

final class BlogThemesSmokeTests: XCTestCase {
    func testThemeManagerConstructs() {
        XCTAssertNoThrow(ThemeManager())
    }

    func testBundledTailwindStylesPostHeadings() throws {
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourceCSS = try String(contentsOf: repoRoot.appendingPathComponent("themes/default/src/tailwind.css"))
        let builtCSS = try String(contentsOf: repoRoot.appendingPathComponent("themes/default/assets/css/tailwind.css"))

        XCTAssertTrue(sourceCSS.contains(".post-content h2"))
        XCTAssertTrue(sourceCSS.contains(".post-content h3"))
        XCTAssertTrue(builtCSS.contains(".post-content h2"))
        XCTAssertTrue(builtCSS.contains(".post-content h3"))
    }
}
