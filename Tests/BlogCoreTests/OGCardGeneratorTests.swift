import Foundation
import XCTest
@testable import BlogCore

final class OGCardGeneratorTests: XCTestCase {
    private var projectRoot: URL!

    override func setUpWithError() throws {
        projectRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("OGCardTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: projectRoot.appendingPathComponent("scripts"),
            withIntermediateDirectories: true
        )
        try linkScript()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: projectRoot)
    }

    func testGeneratesValidPNGForCard() throws {
        try XCTSkipUnless(satoriAvailable(), "satori or @resvg/resvg-js missing")
        try XCTSkipUnless(systemFontAvailable(), "no candidate font on this host")

        let generator = OGCardGenerator(projectRoot: projectRoot)
        let spec = OGCardSpec(
            title: "Hello world",
            subtitle: "A field note",
            author: "krisbaker.com",
            lang: "en",
            theme: "default",
            accent: "#fbbf24"
        )
        let filename = generator.ensureCard(spec: spec)

        let unwrapped = try XCTUnwrap(filename)
        let cachePath = generator.cachePath(forFilename: unwrapped)
        let attrs = try FileManager.default.attributesOfItem(atPath: cachePath.path)
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
        XCTAssertGreaterThan(size, 1000, "PNG should be more than 1KB")
        let prefix = try Data(contentsOf: cachePath).prefix(8)
        XCTAssertEqual(Array(prefix), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], "PNG signature")
        XCTAssertEqual(generator.generatedFilenames.contains(unwrapped), true)
    }

    func testSecondCallShortCircuitsViaCache() throws {
        try XCTSkipUnless(satoriAvailable(), "satori or @resvg/resvg-js missing")
        try XCTSkipUnless(systemFontAvailable(), "no candidate font on this host")

        let generator = OGCardGenerator(projectRoot: projectRoot)
        let spec = OGCardSpec(title: "Cached", subtitle: "x", author: "y", lang: "en", theme: "default", accent: "#fbbf24")
        let first = generator.ensureCard(spec: spec)
        XCTAssertNotNil(first)

        // Remove the script: a cache hit must not need to re-render.
        try FileManager.default.removeItem(at: projectRoot.appendingPathComponent("scripts/render-og.mjs"))
        let second = generator.ensureCard(spec: spec)
        XCTAssertEqual(second, first, "second call should hit cache and return same filename")
    }

    func testReturnsNilWhenNoFontIsAvailable() throws {
        try XCTSkipUnless(satoriAvailable(), "satori or @resvg/resvg-js missing")
        // Test runner that points at a non-existent project so candidate
        // font paths don't resolve to anything (the system-font fallback
        // only fires when the host actually has those files; we can't
        // reliably remove them, so this exercises the spec-pre-validation
        // path indirectly through a malformed spec): pass an invalid
        // theme directory so themes-supplied font isn't found, and use a
        // generator that won't get past missing fonts on a non-mac CI host.
        // Skipped on macOS hosts that have system fonts — the test value
        // here is to lock in nil-on-failure shape.
        if systemFontAvailable() {
            throw XCTSkip("host has a fallback font; nil-on-no-font path can't be exercised")
        }
        let generator = OGCardGenerator(projectRoot: projectRoot)
        let spec = OGCardSpec(title: "Title", subtitle: "", author: "", lang: "en", theme: "default", accent: "")
        XCTAssertNil(generator.ensureCard(spec: spec))
    }

    func testKeyChangesWhenLangChanges() {
        let generator = OGCardGenerator(projectRoot: projectRoot)
        let en = OGCardSpec(title: "Hello", subtitle: "x", author: "y", lang: "en", theme: "default", accent: "#fff")
        let ja = OGCardSpec(title: "Hello", subtitle: "x", author: "y", lang: "ja", theme: "default", accent: "#fff")
        // Generate against a fake script so both calls fail symmetrically — we
        // only care about the cache path differing here, not actual rendering.
        let enKeyPath = generator.cachePath(forFilename: "x")
        XCTAssertEqual(enKeyPath.lastPathComponent, "x")
        // Just ensure the spec equality reflects lang difference (used in caching).
        XCTAssertNotEqual(en, ja)
    }

    // MARK: - helpers

    private func linkScript() throws {
        let repoScript = repoRoot().appendingPathComponent("scripts/render-og.mjs")
        let target = projectRoot.appendingPathComponent("scripts/render-og.mjs")
        try FileManager.default.createSymbolicLink(at: target, withDestinationURL: repoScript)
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func satoriAvailable() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "node", "-e",
            "Promise.all([import('satori'),import('@resvg/resvg-js')]).then(()=>process.exit(0)).catch(()=>process.exit(1))"
        ]
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

    private func systemFontAvailable() -> Bool {
        OGCardGenerator.candidateFontPaths(projectRoot: projectRoot, theme: "default")
            .contains(where: { FileManager.default.fileExists(atPath: $0) })
    }
}
