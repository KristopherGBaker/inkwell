import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import BlogCore

final class CoverImageResolutionTests: XCTestCase {
    func testResolverReturnsResponsiveImageWithSrcsetForLocalAsset() throws {
        try XCTSkipUnless(sharpAvailable(), "sharp not installed")
        let projectRoot = try makeProjectRoot()
        defer { try? FileManager.default.removeItem(at: projectRoot) }
        try writeJPEG(width: 1800, height: 1200, to: projectRoot.appendingPathComponent("static/cover.jpg"))

        let resolver = ResponsiveImageResolver(
            projectRoot: projectRoot,
            spec: .init(widths: [480, 800, 1200, 1600], formats: ["avif", "webp"], minBytes: 0)
        )
        let image = resolver.resolve(path: "/static/cover.jpg", alt: "Cover")

        let unwrapped = try XCTUnwrap(image)
        XCTAssertEqual(unwrapped.alt, "Cover")
        XCTAssertEqual(unwrapped.width, 1800)
        XCTAssertEqual(unwrapped.height, 1200)
        XCTAssertTrue(unwrapped.src.hasPrefix("/_processed/"), "fallback src points at processed dir")
        XCTAssertTrue(unwrapped.srcset.contains("/_processed/"))
        XCTAssertTrue(unwrapped.srcset.contains("480w"))
        XCTAssertTrue(unwrapped.srcset.contains("1600w"))
        XCTAssertTrue(unwrapped.srcsetAvif.contains(".avif"))
        XCTAssertEqual(unwrapped.sizes, "100vw")
        XCTAssertEqual(resolver.usedVariantFilenames.count, 8, "tracks all variants for output copy")
    }

    func testResolverReturnsNilForNonProjectAsset() {
        let projectRoot = try? makeProjectRoot()
        defer { projectRoot.map { try? FileManager.default.removeItem(at: $0) } }
        let resolver = ResponsiveImageResolver(projectRoot: projectRoot ?? URL(fileURLWithPath: "/"))
        XCTAssertNil(resolver.resolve(path: "https://example.com/foo.jpg", alt: "x"))
        XCTAssertNil(resolver.resolve(path: "/static/missing.jpg", alt: "x"))
    }

    func testCoverImageContextExposesSrcsetWhenResolvable() throws {
        try XCTSkipUnless(sharpAvailable(), "sharp not installed")
        let projectRoot = try makeProjectRoot()
        defer { try? FileManager.default.removeItem(at: projectRoot) }
        try writeJPEG(width: 1800, height: 1200, to: projectRoot.appendingPathComponent("static/cover.jpg"))

        let post = """
        ---
        title: Cover Test
        date: 2026-04-12T00:00:00Z
        slug: cover-test
        coverImage: /static/cover.jpg
        ---

        body
        """
        try post.write(
            to: projectRoot.appendingPathComponent("content/posts/2026-04-12-cover-test.md"),
            atomically: true,
            encoding: .utf8
        )

        let report = try BuildPipeline().run(in: projectRoot)
        XCTAssertEqual(report.errors.count, 0)

        let processedDir = projectRoot.appendingPathComponent("docs/_processed")
        let processedFiles = try FileManager.default.contentsOfDirectory(atPath: processedDir.path)
        XCTAssertGreaterThan(processedFiles.count, 0, "cover image variants copied to docs/_processed/")

        let postHTML = try String(contentsOf: projectRoot.appendingPathComponent("docs/posts/cover-test/index.html"))
        XCTAssertTrue(postHTML.contains("/_processed/"), "rendered post should reference processed variants somewhere")
    }

    func testCoverImageFallsBackToBasicShapeWhenUnresolvable() throws {
        let projectRoot = try makeProjectRoot()
        defer { try? FileManager.default.removeItem(at: projectRoot) }

        let post = """
        ---
        title: External Cover
        date: 2026-04-12T00:00:00Z
        slug: external-cover
        coverImage: https://cdn.example.com/cover.jpg
        ---

        body
        """
        try post.write(
            to: projectRoot.appendingPathComponent("content/posts/2026-04-12-external.md"),
            atomically: true,
            encoding: .utf8
        )

        let report = try BuildPipeline().run(in: projectRoot)
        XCTAssertEqual(report.errors.count, 0)

        let postHTML = try String(contentsOf: projectRoot.appendingPathComponent("docs/posts/external-cover/index.html"))
        XCTAssertTrue(postHTML.contains("https://cdn.example.com/cover.jpg"))
    }

    // MARK: - helpers

    private func makeProjectRoot() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CoverImageTests-\(UUID().uuidString)", isDirectory: true)
        for sub in ["static", "scripts", "content/posts"] {
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent(sub),
                withIntermediateDirectories: true
            )
        }
        let scriptSource = repoRoot().appendingPathComponent("scripts/process-image.mjs")
        let scriptTarget = root.appendingPathComponent("scripts/process-image.mjs")
        try FileManager.default.createSymbolicLink(at: scriptTarget, withDestinationURL: scriptSource)
        return root
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func sharpAvailable() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["node", "-e", "import('sharp').then(()=>process.exit(0)).catch(()=>process.exit(1))"]
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

    private func writeJPEG(width: Int, height: Int, to url: URL) throws {
        let cs = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: cs, bitmapInfo: bitmapInfo
        ) else {
            throw NSError(domain: "CoverImageResolutionTests", code: 1)
        }
        let bands = 16
        for i in 0..<bands {
            let progress = Double(i) / Double(bands)
            ctx.setFillColor(red: progress, green: 1.0 - progress, blue: 0.4, alpha: 1.0)
            ctx.fill(CGRect(x: 0, y: i * (height / bands), width: width, height: height / bands))
        }
        guard let image = ctx.makeImage() else {
            throw NSError(domain: "CoverImageResolutionTests", code: 2)
        }
        let buffer = NSMutableData()
        let typeID = (UTType.jpeg.identifier as CFString)
        guard let dest = CGImageDestinationCreateWithData(buffer, typeID, 1, nil) else {
            throw NSError(domain: "CoverImageResolutionTests", code: 3)
        }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "CoverImageResolutionTests", code: 4)
        }
        try (buffer as Data).write(to: url, options: .atomic)
    }
}
