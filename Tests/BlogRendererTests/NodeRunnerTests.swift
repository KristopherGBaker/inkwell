import XCTest
@testable import BlogRenderer

final class NodeRunnerTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("NodeRunnerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testReturnsNilWhenScriptIsMissing() {
        let runner = NodeRunner()
        let missing = tempRoot.appendingPathComponent("does-not-exist.mjs")
        XCTAssertNil(runner.run(script: missing, args: []))
    }

    func testReturnsStdoutWhenScriptSucceeds() throws {
        try XCTSkipUnless(nodeAvailable(), "node not on PATH")
        let runner = NodeRunner()
        let script = try writeScript("process.stdout.write('hello-' + process.argv[2]);")
        let output = runner.run(script: script, args: ["world"])
        XCTAssertEqual(output.flatMap { String(data: $0, encoding: .utf8) }, "hello-world")
    }

    func testReturnsNilWhenScriptExitsNonZero() throws {
        try XCTSkipUnless(nodeAvailable(), "node not on PATH")
        let runner = NodeRunner()
        let script = try writeScript("process.stdout.write('partial'); process.exit(1);")
        XCTAssertNil(runner.run(script: script, args: []))
    }

    func testReturnsNilWhenScriptProducesEmptyStdout() throws {
        try XCTSkipUnless(nodeAvailable(), "node not on PATH")
        let runner = NodeRunner()
        let script = try writeScript("// no output")
        XCTAssertNil(runner.run(script: script, args: []))
    }

    private func writeScript(_ source: String) throws -> URL {
        let url = tempRoot.appendingPathComponent("script-\(UUID().uuidString).mjs")
        try source.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func nodeAvailable() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["node", "--version"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
