import XCTest
@testable import BlogCore

final class SchemaValidatorTests: XCTestCase {
    func testMissingRequiredTitleFailsValidation() {
        let fm = PostFrontMatter(title: nil, date: "2026-03-05T00:00:00Z", slug: "test")
        XCTAssertThrowsError(try SchemaValidator.validate(frontMatter: fm))
    }

    func testValidFrontMatterPassesValidation() {
        let fm = PostFrontMatter(title: "Hello", date: "2026-03-05T00:00:00Z", slug: "hello")
        XCTAssertNoThrow(try SchemaValidator.validate(frontMatter: fm))
    }
}
