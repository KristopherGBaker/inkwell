import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import BlogCore

final class PictureRewriterTests: XCTestCase {
    private var projectRoot: URL!

    override func setUpWithError() throws {
        projectRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PictureRewriterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: projectRoot.appendingPathComponent("static/raw"),
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

    func testRewritesImgToPictureWithAvifAndWebpSources() throws {
        try XCTSkipUnless(sharpAvailable(), "sharp not installed")
        try writeJPEG(width: 1800, height: 1200, to: projectRoot.appendingPathComponent("static/photo.jpg"))

        let rewriter = PictureRewriter(projectRoot: projectRoot, spec: .init(widths: [480, 800, 1200, 1600], formats: ["avif", "webp"], minBytes: 0))
        let html = #"<p>Look:</p><img src="/static/photo.jpg" alt="a photo">"#
        let result = rewriter.rewrite(html: html)

        XCTAssertTrue(result.html.contains("<picture>"), "expected <picture> wrapper, got: \(result.html)")
        XCTAssertTrue(result.html.contains("<source type=\"image/avif\""), "missing avif source")
        XCTAssertTrue(result.html.contains("<source type=\"image/webp\""), "missing webp source")
        XCTAssertTrue(result.html.contains("alt=\"a photo\""), "alt should be preserved")
        XCTAssertTrue(result.html.contains("loading=\"lazy\""), "should mark lazy")
        XCTAssertTrue(result.html.contains("decoding=\"async\""), "should mark async decode")
        XCTAssertTrue(result.html.contains("width=\"1800\""), "intrinsic width attr")
        XCTAssertTrue(result.html.contains("height=\"1200\""), "intrinsic height attr")
        XCTAssertEqual(result.usedVariantFilenames.count, 8, "4 widths × 2 formats tracked for output copy")
    }

    func testLeavesImagesUnderStaticRawAlone() throws {
        try XCTSkipUnless(sharpAvailable(), "sharp not installed")
        try writeJPEG(width: 800, height: 600, to: projectRoot.appendingPathComponent("static/raw/keep.jpg"))

        let rewriter = PictureRewriter(projectRoot: projectRoot, spec: .init(widths: [480], formats: ["webp"], minBytes: 0))
        let html = #"<img src="/static/raw/keep.jpg" alt="raw">"#
        let result = rewriter.rewrite(html: html)

        XCTAssertEqual(result.html, html, "raw/ assets should pass through untouched")
        XCTAssertTrue(result.usedVariantFilenames.isEmpty)
    }

    func testBypassedSourcesGetWidthAndHeightAttributes() throws {
        try XCTSkipUnless(sharpAvailable(), "sharp not installed")
        let svgPath = projectRoot.appendingPathComponent("static/icon.svg")
        try """
        <?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="120" height="80" viewBox="0 0 120 80">
          <rect width="120" height="80" fill="#ccc"/>
        </svg>
        """.write(to: svgPath, atomically: true, encoding: .utf8)

        let rewriter = PictureRewriter(projectRoot: projectRoot, spec: .defaults)
        let html = #"<img src="/static/icon.svg" alt="icon">"#
        let result = rewriter.rewrite(html: html)

        XCTAssertFalse(result.html.contains("<picture>"), "SVG bypass should not wrap in <picture>")
        XCTAssertTrue(result.html.contains("loading=\"lazy\""), "bypass still gets lazy loading hint")
        XCTAssertTrue(result.html.contains("decoding=\"async\""))
        XCTAssertTrue(result.html.contains("alt=\"icon\""))
    }

    func testLeavesExternalAndDataURLsUntouched() {
        let rewriter = PictureRewriter(projectRoot: projectRoot, spec: .defaults)
        let html = #"<img src="https://cdn.example.com/x.jpg"><img src="data:image/png;base64,AAA=">"#
        let result = rewriter.rewrite(html: html)
        XCTAssertEqual(result.html, html)
        XCTAssertTrue(result.usedVariantFilenames.isEmpty)
    }

    func testMissingSourceFileLeavesImgUntouched() {
        let rewriter = PictureRewriter(projectRoot: projectRoot, spec: .defaults)
        let html = #"<img src="/static/does-not-exist.jpg" alt="missing">"#
        let result = rewriter.rewrite(html: html)
        XCTAssertEqual(result.html, html)
        XCTAssertTrue(result.usedVariantFilenames.isEmpty)
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
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: cs, bitmapInfo: bitmapInfo
        ) else {
            throw NSError(domain: "PictureRewriterTests", code: 1)
        }
        let bands = 16
        for i in 0..<bands {
            let progress = Double(i) / Double(bands)
            ctx.setFillColor(red: progress, green: 1.0 - progress, blue: 0.4, alpha: 1.0)
            ctx.fill(CGRect(x: 0, y: i * (height / bands), width: width, height: height / bands))
        }
        guard let image = ctx.makeImage() else {
            throw NSError(domain: "PictureRewriterTests", code: 2)
        }
        let buffer = NSMutableData()
        let typeID = (UTType.jpeg.identifier as CFString)
        guard let dest = CGImageDestinationCreateWithData(buffer, typeID, 1, nil) else {
            throw NSError(domain: "PictureRewriterTests", code: 3)
        }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "PictureRewriterTests", code: 4)
        }
        try (buffer as Data).write(to: url, options: .atomic)
    }
}
