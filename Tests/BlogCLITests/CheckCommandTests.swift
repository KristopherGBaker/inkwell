import ArgumentParser
import Foundation
import XCTest
@testable import BlogCLI
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

    func testLinkCheckerIgnoresFragmentInInternalLinkTarget() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("docs/post"), withIntermediateDirectories: true)
        try "<a href=\"/post/#intro\">post</a>".write(to: root.appendingPathComponent("docs/index.html"), atomically: true, encoding: .utf8)
        try "<h1 id=\"intro\">Intro</h1>".write(to: root.appendingPathComponent("docs/post/index.html"), atomically: true, encoding: .utf8)

        let result = LinkChecker().check(projectRoot: root)

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.brokenLinks, [])
    }

    func testLinkCheckerIgnoresQueryStringInInternalLinkTarget() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("docs/search"), withIntermediateDirectories: true)
        try "<a href=\"/search/?q=x\">search</a>".write(to: root.appendingPathComponent("docs/index.html"), atomically: true, encoding: .utf8)
        try "<h1>Search</h1>".write(to: root.appendingPathComponent("docs/search/index.html"), atomically: true, encoding: .utf8)

        let result = LinkChecker().check(projectRoot: root)

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.brokenLinks, [])
    }

    func testCheckJSONIncludesErrorsAndFails() throws {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root.appendingPathComponent("content/posts"), withIntermediateDirectories: true)

        let markdown = """
        ---
        title: Example
        date: 2026-03-08T00:00:00Z
        slug: example
        coverImage: /assets/images/missing.png
        ---

        Hello world
        """
        try markdown.write(to: root.appendingPathComponent("content/posts/2026-03-08-example.md"), atomically: true, encoding: .utf8)

        let oldDirectory = fm.currentDirectoryPath
        _ = fm.changeCurrentDirectoryPath(root.path)
        defer { _ = fm.changeCurrentDirectoryPath(oldDirectory) }

        var command = CheckCommand()
        command.json = true

        let output = captureStandardOutput {
            do {
                try command.run()
                XCTFail("Expected check command to fail")
            } catch {
                XCTAssertEqual(error as? ExitCode, .failure)
            }
        }

        let data = try XCTUnwrap(output.data(using: .utf8))
        let payload = try JSONDecoder().decode(CheckCommandPayload.self, from: data)

        XCTAssertFalse(payload.ok)
        XCTAssertEqual(payload.brokenLinks, [])
        XCTAssertEqual(payload.errors.count, 1)
        XCTAssertTrue(payload.errors[0].contains("missing.png"))
    }

    func testCheckJSONFailsForMalformedConfig() throws {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let invalidJSON = """
        {
          "title": 42
        }
        """
        try invalidJSON.write(to: root.appendingPathComponent("blog.config.json"), atomically: true, encoding: .utf8)

        let oldDirectory = fm.currentDirectoryPath
        _ = fm.changeCurrentDirectoryPath(root.path)
        defer { _ = fm.changeCurrentDirectoryPath(oldDirectory) }

        var command = CheckCommand()
        command.json = true

        let output = captureStandardOutput {
            do {
                try command.run()
                XCTFail("Expected check command to fail")
            } catch {
                XCTAssertEqual(error as? ExitCode, .failure)
            }
        }

        let data = try XCTUnwrap(output.data(using: .utf8))
        let payload = try JSONDecoder().decode(CheckCommandPayload.self, from: data)

        XCTAssertFalse(payload.ok)
        XCTAssertEqual(payload.brokenLinks, [])
        XCTAssertEqual(payload.errors.count, 1)
        XCTAssertTrue(payload.errors[0].contains("blog.config.json"))
    }

    func testCheckJSONFailsForTaxonomySlugCollision() throws {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root.appendingPathComponent("content/posts"), withIntermediateDirectories: true)

        let firstPost = """
        ---
        title: First
        date: 2026-03-08T00:00:00Z
        slug: first
        tags: [Swift]
        ---

        Body
        """
        try firstPost.write(to: root.appendingPathComponent("content/posts/2026-03-08-first.md"), atomically: true, encoding: .utf8)

        let secondPost = """
        ---
        title: Second
        date: 2026-03-09T00:00:00Z
        slug: second
        tags: [swift!]
        ---

        Body
        """
        try secondPost.write(to: root.appendingPathComponent("content/posts/2026-03-09-second.md"), atomically: true, encoding: .utf8)

        let oldDirectory = fm.currentDirectoryPath
        _ = fm.changeCurrentDirectoryPath(root.path)
        defer { _ = fm.changeCurrentDirectoryPath(oldDirectory) }

        var command = CheckCommand()
        command.json = true

        let output = captureStandardOutput {
            do {
                try command.run()
                XCTFail("Expected check command to fail")
            } catch {
                XCTAssertEqual(error as? ExitCode, .failure)
            }
        }

        let data = try XCTUnwrap(output.data(using: .utf8))
        let payload = try JSONDecoder().decode(CheckCommandPayload.self, from: data)

        XCTAssertFalse(payload.ok)
        XCTAssertEqual(payload.brokenLinks, [])
        XCTAssertEqual(payload.errors, ["Taxonomy slug collision for tags 'swift': Swift, swift!"])
    }

    private func captureStandardOutput(_ operation: () -> Void) -> String {
        let pipe = Pipe()
        let stdoutDescriptor = dup(STDOUT_FILENO)
        XCTAssertNotEqual(stdoutDescriptor, -1)
        fflush(stdout)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

        operation()
        fflush(stdout)

        dup2(stdoutDescriptor, STDOUT_FILENO)
        close(stdoutDescriptor)
        pipe.fileHandleForWriting.closeFile()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(bytes: data, encoding: .utf8) ?? ""
    }
}

private struct CheckCommandPayload: Decodable {
    let brokenLinks: [String]
    let errors: [String]
    let ok: Bool
}
