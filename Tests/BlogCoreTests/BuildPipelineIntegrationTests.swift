import Foundation
import XCTest
@testable import BlogCore

final class BuildPipelineIntegrationTests: XCTestCase {
    func testBuildWritesPostAndIndexPages() throws {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: temp.appendingPathComponent("content/posts"), withIntermediateDirectories: true)

        let post = """
        ---
        title: Hello World
        date: 2026-03-05T00:00:00Z
        slug: hello-world
        ---

        Test post body
        """
        try post.write(to: temp.appendingPathComponent("content/posts/2026-03-05-hello-world.md"), atomically: true, encoding: .utf8)

        let report = try BuildPipeline().run(in: temp)
        XCTAssertEqual(report.errors.count, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/index.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/posts/hello-world/index.html").path))
    }
}
