import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import BlogCore

final class ImageVariantGeneratorTests: XCTestCase {
    private var projectRoot: URL!

    override func setUpWithError() throws {
        projectRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ImageVariantTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: projectRoot.appendingPathComponent("static"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: projectRoot.appendingPathComponent("scripts"),
            withIntermediateDirectories: true
        )
        try linkScript()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: projectRoot)
    }

    func testGeneratesAvifAndWebpAtAllRequestedWidths() throws {
        try XCTSkipUnless(sharpAvailable(), "sharp not installed")
        let source = projectRoot.appendingPathComponent("static/photo.jpg")
        try writeJPEG(width: 1800, height: 1200, to: source)

        let generator = ImageVariantGenerator(projectRoot: projectRoot)
        let spec = ImageVariantSpec(widths: [480, 800, 1200, 1600], formats: ["avif", "webp"], minBytes: 0)
        let result = generator.ensureVariants(source: source, spec: spec)

        let unwrapped = try XCTUnwrap(result)
        XCTAssertFalse(unwrapped.metadata.bypassed)
        XCTAssertEqual(unwrapped.variants.count, 8, "4 widths × 2 formats")

        let widths = Set(unwrapped.variants.map(\.width))
        XCTAssertEqual(widths, Set([480, 800, 1200, 1600]))
        XCTAssertEqual(Set(unwrapped.variants.map(\.format)), Set(["avif", "webp"]))

        for variant in unwrapped.variants {
            let path = generator.cachePath(for: variant)
            let attrs = try FileManager.default.attributesOfItem(atPath: path.path)
            let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
            XCTAssertGreaterThan(size, 0, "variant \(variant.width).\(variant.format) should be non-empty")
        }
    }

    func testBypassesSVGSources() throws {
        try XCTSkipUnless(sharpAvailable(), "sharp not installed")
        let source = projectRoot.appendingPathComponent("static/icon.svg")
        try """
        <?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="120" height="80" viewBox="0 0 120 80">
          <rect width="120" height="80" fill="#cccccc"/>
        </svg>
        """.write(to: source, atomically: true, encoding: .utf8)

        let generator = ImageVariantGenerator(projectRoot: projectRoot)
        let result = generator.ensureVariants(source: source, spec: .defaults)

        let unwrapped = try XCTUnwrap(result)
        XCTAssertTrue(unwrapped.metadata.bypassed)
        XCTAssertEqual(unwrapped.metadata.reason, "svg")
        XCTAssertTrue(unwrapped.variants.isEmpty)
    }

    func testSecondCallShortCircuitsViaCache() throws {
        try XCTSkipUnless(sharpAvailable(), "sharp not installed")
        let source = projectRoot.appendingPathComponent("static/photo.jpg")
        try writeJPEG(width: 800, height: 600, to: source)

        let generator = ImageVariantGenerator(projectRoot: projectRoot)
        let spec = ImageVariantSpec(widths: [480], formats: ["webp"], minBytes: 0)
        let first = generator.ensureVariants(source: source, spec: spec)
        XCTAssertNotNil(first)

        // Remove the script: a cache hit must not need to spawn node again.
        try FileManager.default.removeItem(at: projectRoot.appendingPathComponent("scripts/process-image.mjs"))

        let second = generator.ensureVariants(source: source, spec: spec)
        XCTAssertEqual(second, first, "second call should hit the cache and return identical manifest")
    }

    func testCapsVariantWidthsAtIntrinsicSourceWidth() throws {
        try XCTSkipUnless(sharpAvailable(), "sharp not installed")
        let source = projectRoot.appendingPathComponent("static/small.jpg")
        try writeJPEG(width: 600, height: 400, to: source)

        let generator = ImageVariantGenerator(projectRoot: projectRoot)
        let spec = ImageVariantSpec(widths: [480, 800, 1200, 1600], formats: ["webp"], minBytes: 0)
        let result = generator.ensureVariants(source: source, spec: spec)

        let unwrapped = try XCTUnwrap(result)
        XCTAssertFalse(unwrapped.metadata.bypassed)
        let widths = Set(unwrapped.variants.map(\.width))
        XCTAssertEqual(widths, Set([480, 600]), "widths above intrinsic should drop, intrinsic should be preserved")
    }

    // MARK: - helpers

    private func linkScript() throws {
        let repoScript = repoRoot().appendingPathComponent("scripts/process-image.mjs")
        let target = projectRoot.appendingPathComponent("scripts/process-image.mjs")
        try FileManager.default.createSymbolicLink(at: target, withDestinationURL: repoScript)
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
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: cs,
            bitmapInfo: bitmapInfo
        ) else {
            throw NSError(domain: "ImageVariantGeneratorTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "ctx"])
        }

        // Stripe pattern keeps the JPEG byte size meaningful even after compression.
        let bands = 16
        for i in 0..<bands {
            let progress = Double(i) / Double(bands)
            ctx.setFillColor(red: progress, green: 1.0 - progress, blue: 0.4, alpha: 1.0)
            ctx.fill(CGRect(x: 0, y: i * (height / bands), width: width, height: height / bands))
        }

        guard let image = ctx.makeImage() else {
            throw NSError(domain: "ImageVariantGeneratorTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "image"])
        }

        let buffer = NSMutableData()
        let typeID = (UTType.jpeg.identifier as CFString)
        guard let dest = CGImageDestinationCreateWithData(buffer, typeID, 1, nil) else {
            throw NSError(domain: "ImageVariantGeneratorTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "dest"])
        }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "ImageVariantGeneratorTests", code: 4, userInfo: [NSLocalizedDescriptionKey: "finalize"])
        }
        try (buffer as Data).write(to: url, options: .atomic)
    }
}
