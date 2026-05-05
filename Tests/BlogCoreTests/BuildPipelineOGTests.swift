import Foundation
import XCTest
@testable import BlogCore

final class BuildPipelineOGTests: XCTestCase {
    func testBuildEmitsOGCardAndOgImageMetaTag() throws {
        try XCTSkipUnless(satoriAvailable(), "satori or @resvg/resvg-js missing")
        try XCTSkipUnless(systemFontAvailable(), "no candidate font on this host")

        let temp = try makeTempBlogProject(extraDirectories: ["scripts"])
        try linkOGScript(into: temp)

        let post = """
        ---
        title: Hello world
        date: 2026-04-12T00:00:00Z
        slug: hello-og
        summary: A test post
        ---

        body
        """
        try post.write(
            to: temp.appendingPathComponent("content/posts/2026-04-12-hello-og.md"),
            atomically: true,
            encoding: .utf8
        )

        let report = try BuildPipeline().run(in: temp)
        XCTAssertEqual(report.errors.count, 0)

        let postHTML = try String(contentsOf: temp.appendingPathComponent("docs/posts/hello-og/index.html"))
        XCTAssertTrue(postHTML.contains("property=\"og:image\""), "post should expose og:image meta")
        XCTAssertTrue(postHTML.contains("name=\"twitter:image\""), "post should expose twitter:image meta")
        XCTAssertTrue(postHTML.contains("/og/"), "og:image should reference /og/<hash>.png")

        let ogDir = temp.appendingPathComponent("docs/og")
        let entries = try FileManager.default.contentsOfDirectory(atPath: ogDir.path)
        let pngFiles = entries.filter { $0.hasSuffix(".png") }
        XCTAssertGreaterThanOrEqual(pngFiles.count, 1, "at least one card written to docs/og/")
    }

    func testFrontMatterOGImageOverrideShortCircuitsGeneration() throws {
        let temp = try makeTempBlogProject(extraDirectories: ["scripts"])

        let post = """
        ---
        title: External
        date: 2026-04-12T00:00:00Z
        slug: external-og
        ogImage: https://cdn.example.com/social.png
        ---

        body
        """
        try post.write(
            to: temp.appendingPathComponent("content/posts/2026-04-12-external-og.md"),
            atomically: true,
            encoding: .utf8
        )

        let report = try BuildPipeline().run(in: temp)
        XCTAssertEqual(report.errors.count, 0)

        let postHTML = try String(contentsOf: temp.appendingPathComponent("docs/posts/external-og/index.html"))
        XCTAssertTrue(postHTML.contains("https://cdn.example.com/social.png"), "external override should appear verbatim")

        // Without the script symlinked, generation can't run — overriding via
        // front-matter must still produce a valid build.
    }

    // MARK: - helpers

    private func linkOGScript(into temp: URL) throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = repoRoot.appendingPathComponent("scripts/render-og.mjs")
        let target = temp.appendingPathComponent("scripts/render-og.mjs")
        try FileManager.default.createSymbolicLink(at: target, withDestinationURL: source)
    }

    private func satoriAvailable() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "node", "-e",
            "Promise.all([import('satori'),import('@resvg/resvg-js')]).then(()=>process.exit(0)).catch(()=>process.exit(1))"
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
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

    private func systemFontAvailable() -> Bool {
        let dummy = URL(fileURLWithPath: "/")
        return OGCardGenerator.candidateFontPaths(projectRoot: dummy, theme: "default")
            .contains(where: { FileManager.default.fileExists(atPath: $0) })
    }
}
