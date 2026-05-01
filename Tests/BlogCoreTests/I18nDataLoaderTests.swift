import Foundation
import XCTest
@testable import BlogCore

final class I18nDataLoaderTests: XCTestCase {
    func testSplitDataFilenameRecognizesLanguageSuffix() {
        let split = DataLoader.splitDataFilename
        XCTAssertEqual(split("resume.yml").base, "resume")
        XCTAssertNil(split("resume.yml").lang)
        XCTAssertEqual(split("resume.ja.yml").base, "resume")
        XCTAssertEqual(split("resume.ja.yml").lang, "ja")
        XCTAssertEqual(split("resume.en-US.json").lang, "en-US")
        XCTAssertEqual(split("plain.yaml").base, "plain")
        XCTAssertNil(split("plain.yaml").lang)
    }

    func testLoadPrefersLanguageVariantWhenPresent() throws {
        let root = makeTempProject()
        try writeFile(root, "data/resume.yml", "summary: english\nstatus: en\n")
        try writeFile(root, "data/resume.ja.yml", "summary: japanese\nstatus: ja\n")

        let en = try DataLoader().load(in: root, lang: "en")
        let ja = try DataLoader().load(in: root, lang: "ja")

        XCTAssertEqual((en["resume"] as? [String: Any])?["summary"] as? String, "english")
        XCTAssertEqual((ja["resume"] as? [String: Any])?["summary"] as? String, "japanese")
    }

    func testLoadFallsBackToUnsuffixedWhenLanguageVariantMissing() throws {
        let root = makeTempProject()
        try writeFile(root, "data/resume.yml", "summary: english\n")
        try writeFile(root, "data/competencies.yml", "core: shared\n")
        try writeFile(root, "data/resume.ja.yml", "summary: japanese\n")
        // Note: no competencies.ja.yml — should fall back to base.

        let ja = try DataLoader().load(in: root, lang: "ja")

        XCTAssertEqual((ja["resume"] as? [String: Any])?["summary"] as? String, "japanese")
        XCTAssertEqual((ja["competencies"] as? [String: Any])?["core"] as? String, "shared")
    }

    func testLoadDefaultLanguageReturnsUnsuffixedFiles() throws {
        let root = makeTempProject()
        try writeFile(root, "data/resume.yml", "summary: english\n")
        try writeFile(root, "data/resume.ja.yml", "summary: japanese\n")

        let result = try DataLoader().load(in: root)

        // Default lang is "en"; resume.yml is the base (no .en.yml exists), so
        // we get the base file.
        XCTAssertEqual((result["resume"] as? [String: Any])?["summary"] as? String, "english")
    }

    private func writeFile(_ root: URL, _ relative: String, _ content: String) throws {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func makeTempProject() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }
}
