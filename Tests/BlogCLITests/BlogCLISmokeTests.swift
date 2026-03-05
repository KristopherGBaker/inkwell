import XCTest
@testable import BlogCLI

final class BlogCLISmokeTests: XCTestCase {
    func testCLITypeLoads() {
        XCTAssertNotNil(BlogCommand.configuration)
    }
}
