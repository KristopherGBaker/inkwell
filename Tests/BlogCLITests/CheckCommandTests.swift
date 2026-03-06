import Foundation
import XCTest
@testable import BlogCore

final class CheckCommandTests: XCTestCase {
    func testCheckFailsOnBrokenInternalLink() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
        let html = "<a href=\"/missing-page/\">missing</a>"
        try html.write(to: root.appendingPathComponent("docs/index.html"), atomically: true, encoding: .utf8)

        let result = LinkChecker().check(projectRoot: root)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.brokenLinks.contains("/missing-page/"))
    }
}
