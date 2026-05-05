import Foundation
import XCTest
@testable import BlogCore

final class MathIntegrationTests: XCTestCase {
    func testPostWithInlineMathRendersKatexHTML() throws {
        try XCTSkipUnless(katexAvailable(), "katex not installed")

        let temp = try makeProjectRoot()
        try writePost(named: "2026-04-12-mass-energy.md", body: """
        ---
        title: Mass Energy
        date: 2026-04-12T00:00:00Z
        slug: mass-energy
        ---

        Einstein wrote $E = mc^2$ on a chalkboard.
        """, in: temp)

        let report = try BuildPipeline().run(in: temp)
        XCTAssertEqual(report.errors.count, 0)

        let html = try String(contentsOf: temp.appendingPathComponent("docs/posts/mass-energy/index.html"))
        XCTAssertTrue(html.contains("<span class=\"math math-inline\">"), "expected inline math wrapper")
        XCTAssertTrue(html.contains("class=\"katex\""), "expected katex output")
        XCTAssertTrue(html.contains("/assets/css/katex.min.css"), "expected katex stylesheet link")
    }

    func testPostWithoutMathOmitsKatexCSS() throws {
        let temp = try makeProjectRoot()
        try writePost(named: "2026-04-12-plain.md", body: """
        ---
        title: Plain Post
        date: 2026-04-12T00:00:00Z
        slug: plain
        ---

        Just text and a sprinkle of `code`.
        """, in: temp)

        let report = try BuildPipeline().run(in: temp)
        XCTAssertEqual(report.errors.count, 0)

        let html = try String(contentsOf: temp.appendingPathComponent("docs/posts/plain/index.html"))
        XCTAssertFalse(html.contains("katex.min.css"), "katex CSS should not be injected without math")
        XCTAssertFalse(html.contains("class=\"math math-inline\""), "no inline math wrapper expected")
    }

    func testCurrencyAmountsDoNotTriggerMath() throws {
        let temp = try makeProjectRoot()
        try writePost(named: "2026-04-12-money.md", body: """
        ---
        title: Money Post
        date: 2026-04-12T00:00:00Z
        slug: money
        ---

        Pay $5 today and $10 tomorrow.
        """, in: temp)

        let report = try BuildPipeline().run(in: temp)
        XCTAssertEqual(report.errors.count, 0)

        let html = try String(contentsOf: temp.appendingPathComponent("docs/posts/money/index.html"))
        XCTAssertFalse(html.contains("class=\"math math-inline\""))
        XCTAssertFalse(html.contains("katex.min.css"))
        XCTAssertTrue(html.contains("Pay $5"), "raw dollar text should survive intact")
    }

    func testBlockMathRendersDisplayKatex() throws {
        try XCTSkipUnless(katexAvailable(), "katex not installed")

        let temp = try makeProjectRoot()
        try writePost(named: "2026-04-12-pythagoras.md", body: """
        ---
        title: Pythagoras
        date: 2026-04-12T00:00:00Z
        slug: pythagoras
        ---

        Right triangles satisfy:

        $$
        a^2 + b^2 = c^2
        $$

        Geometry, baby.
        """, in: temp)

        let report = try BuildPipeline().run(in: temp)
        XCTAssertEqual(report.errors.count, 0)

        let html = try String(contentsOf: temp.appendingPathComponent("docs/posts/pythagoras/index.html"))
        XCTAssertTrue(html.contains("<div class=\"math math-block\">"))
        XCTAssertTrue(html.contains("katex-display"))
    }

    // MARK: - helpers

    private func makeProjectRoot() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MathIntegrationTests-\(UUID().uuidString)", isDirectory: true)
        for sub in ["scripts", "content/posts"] {
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent(sub),
                withIntermediateDirectories: true
            )
        }
        let scriptSource = repoRoot().appendingPathComponent("scripts/render-math.mjs")
        let scriptTarget = root.appendingPathComponent("scripts/render-math.mjs")
        try FileManager.default.createSymbolicLink(at: scriptTarget, withDestinationURL: scriptSource)
        return root
    }

    private func writePost(named filename: String, body: String, in projectRoot: URL) throws {
        try body.write(
            to: projectRoot.appendingPathComponent("content/posts/\(filename)"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func katexAvailable() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["node", "-e", "import('katex').then(()=>process.exit(0)).catch(()=>process.exit(1))"]
        process.currentDirectoryURL = repoRoot()
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
