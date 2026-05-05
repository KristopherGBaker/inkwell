import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import BlogCore

final class BuildPipelinePictureTests: XCTestCase {
    func testBuildEmitsPictureMarkupAndCopiesVariantsToOutput() throws {
        try XCTSkipUnless(sharpAvailable(), "sharp not installed")
        let temp = try makeTempBlogProject(extraDirectories: ["static/posts/has-image", "scripts"])
        try linkProcessImageScript(into: temp)

        let imageURL = temp.appendingPathComponent("static/posts/has-image/photo.jpg")
        try writeJPEG(width: 1800, height: 1200, to: imageURL)

        let post = """
        ---
        title: Has Image
        date: 2026-04-12T00:00:00Z
        slug: has-image
        ---

        ![alt text](/static/posts/has-image/photo.jpg)
        """
        try post.write(
            to: temp.appendingPathComponent("content/posts/2026-04-12-has-image.md"),
            atomically: true,
            encoding: .utf8
        )

        let report = try BuildPipeline().run(in: temp)
        XCTAssertEqual(report.errors.count, 0)

        let postHTML = try String(contentsOf: temp.appendingPathComponent("docs/posts/has-image/index.html"))
        XCTAssertTrue(postHTML.contains("<picture>"), "post HTML should contain <picture>: \(postHTML)")
        XCTAssertTrue(postHTML.contains("<source type=\"image/avif\""))
        XCTAssertTrue(postHTML.contains("<source type=\"image/webp\""))
        XCTAssertTrue(postHTML.contains("loading=\"lazy\""))

        let processedDir = temp.appendingPathComponent("docs/_processed")
        let processedFiles = try FileManager.default.contentsOfDirectory(atPath: processedDir.path)
        XCTAssertEqual(processedFiles.count, 8, "4 widths × 2 formats should land in _processed/")
    }

    // MARK: - helpers

    private func linkProcessImageScript(into temp: URL) throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = repoRoot.appendingPathComponent("scripts/process-image.mjs")
        let target = temp.appendingPathComponent("scripts/process-image.mjs")
        try FileManager.default.createSymbolicLink(at: target, withDestinationURL: source)
    }

    private func sharpAvailable() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["node", "-e", "import('sharp').then(()=>process.exit(0)).catch(()=>process.exit(1))"]
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

    private func writeJPEG(width: Int, height: Int, to url: URL) throws {
        let cs = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: cs, bitmapInfo: bitmapInfo
        ) else {
            throw NSError(domain: "BuildPipelinePictureTests", code: 1)
        }
        let bands = 16
        for i in 0..<bands {
            let progress = Double(i) / Double(bands)
            ctx.setFillColor(red: progress, green: 1.0 - progress, blue: 0.4, alpha: 1.0)
            ctx.fill(CGRect(x: 0, y: i * (height / bands), width: width, height: height / bands))
        }
        guard let image = ctx.makeImage() else {
            throw NSError(domain: "BuildPipelinePictureTests", code: 2)
        }
        let buffer = NSMutableData()
        let typeID = (UTType.jpeg.identifier as CFString)
        guard let dest = CGImageDestinationCreateWithData(buffer, typeID, 1, nil) else {
            throw NSError(domain: "BuildPipelinePictureTests", code: 3)
        }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "BuildPipelinePictureTests", code: 4)
        }
        try (buffer as Data).write(to: url, options: .atomic)
    }
}
