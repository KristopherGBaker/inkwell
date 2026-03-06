import XCTest
@testable import BlogThemes

final class BlogThemesSmokeTests: XCTestCase {
    func testThemeManagerConstructs() {
        XCTAssertNoThrow(ThemeManager())
    }
}
