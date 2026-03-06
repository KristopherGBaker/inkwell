import Foundation
import XCTest
@testable import BlogPreview

final class PreviewServerTests: XCTestCase {
    func testResolvesDirectoryRouteToIndexFile() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("posts/welcome"), withIntermediateDirectories: true)
        try "ok".write(to: root.appendingPathComponent("posts/welcome/index.html"), atomically: true, encoding: .utf8)

        let server = PreviewServer(root: root, port: 8000)
        let resolved = server.resolvedFilePath(for: "posts/welcome/")

        XCTAssertEqual(resolved, root.appendingPathComponent("posts/welcome/index.html").path)
    }
}
