import XCTest
@testable import BlogPlugins

final class BlogPluginsSmokeTests: XCTestCase {
    func testPluginManagerConstructs() {
        XCTAssertNoThrow(PluginManager())
    }
}
