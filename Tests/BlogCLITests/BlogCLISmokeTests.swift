import Foundation
import XCTest
@testable import BlogCLI

final class BlogCLISmokeTests: XCTestCase {
    func testCLITypeLoads() {
        XCTAssertNotNil(BlogCommand.configuration)
    }

    func testSlugifyGeneratesExpectedSlug() {
        XCTAssertEqual(slugify("Hello World"), "hello-world")
    }

    func testInitCreatesBaseFiles() throws {
        let fm = FileManager.default
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)
        let old = fm.currentDirectoryPath
        _ = fm.changeCurrentDirectoryPath(temp.path)
        defer { _ = fm.changeCurrentDirectoryPath(old) }

        var command = InitCommand()
        try command.run()

        XCTAssertTrue(fm.fileExists(atPath: temp.appendingPathComponent("blog.config.json").path))
        XCTAssertTrue(fm.fileExists(atPath: temp.appendingPathComponent("content/posts").path))
    }
}
