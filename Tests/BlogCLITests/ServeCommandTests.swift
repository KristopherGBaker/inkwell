import ArgumentParser
import Foundation
import XCTest
@testable import BlogCLI

final class ServeCommandTests: XCTestCase {
    func testParsesWatchFlag() throws {
        let command = try ServeCommand.parse(["--watch"])

        XCTAssertTrue(command.watch)
        XCTAssertEqual(command.port, 8000)
    }

    func testWatchDefaultsToFalse() throws {
        let command = try ServeCommand.parse([])

        XCTAssertFalse(command.watch)
    }

    func testWatchExclusionsDoNotExcludePublicWhenOutputDirectoryIsPublic() {
        let root = URL(fileURLWithPath: "/tmp/project")

        XCTAssertEqual(ServeCommand.watchedExclusions(root: root, outputDirectory: root.appendingPathComponent("public")), [])
    }

    func testWatchExclusionsExcludeNestedOutputDirectoryUnderPublic() {
        let root = URL(fileURLWithPath: "/tmp/project")
        let outputDirectory = root.appendingPathComponent("public/site")

        XCTAssertEqual(ServeCommand.watchedExclusions(root: root, outputDirectory: outputDirectory), [outputDirectory])
    }
}
