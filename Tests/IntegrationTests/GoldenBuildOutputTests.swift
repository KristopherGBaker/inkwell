import Foundation
import XCTest
@testable import BlogCore

final class GoldenBuildOutputTests: XCTestCase {
    func testExampleBlogBuildMatchesGoldenOutput() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let exampleRoot = root.appendingPathComponent("examples/personal-blog")

        _ = try BuildPipeline().run(in: exampleRoot)
        let output = try String(contentsOf: exampleRoot.appendingPathComponent("docs/index.html"))
        let golden = try String(contentsOf: root.appendingPathComponent("Tests/Fixtures/html/example-index.html"))

        XCTAssertEqual(normalize(output), normalize(golden))
    }

    private func normalize(_ value: String) -> String {
        value.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: " ", with: "")
    }
}
