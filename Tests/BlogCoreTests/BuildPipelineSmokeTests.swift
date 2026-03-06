import XCTest
@testable import BlogCore

final class BuildPipelineSmokeTests: XCTestCase {
    func testPipelineConstructs() {
        XCTAssertNoThrow(BuildPipeline())
    }
}
