import XCTest
@testable import BlogCore

final class BuildCacheTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BuildCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testPathPlacesArtifactUnderInkwellCacheCategory() {
        let cache = BuildCache(projectRoot: tempRoot)
        let url = cache.path(for: "images", key: "abc123", ext: "webp")
        XCTAssertEqual(url.path, tempRoot.appendingPathComponent(".inkwell-cache/images/abc123.webp").path)
    }

    func testPathTrimsLeadingDotInExtension() {
        let cache = BuildCache(projectRoot: tempRoot)
        let url = cache.path(for: "og", key: "abc", ext: ".png")
        XCTAssertEqual(url.lastPathComponent, "abc.png")
    }

    func testExistsIsFalseBeforeWrite() {
        let cache = BuildCache(projectRoot: tempRoot)
        XCTAssertFalse(cache.exists(for: "images", key: "missing", ext: "webp"))
    }

    func testWriteCreatesFileAndExistsBecomesTrue() throws {
        let cache = BuildCache(projectRoot: tempRoot)
        try cache.write(Data("payload".utf8), for: "images", key: "k", ext: "bin")
        XCTAssertTrue(cache.exists(for: "images", key: "k", ext: "bin"))
        let written = try Data(contentsOf: cache.path(for: "images", key: "k", ext: "bin"))
        XCTAssertEqual(String(data: written, encoding: .utf8), "payload")
    }

    func testWriteOverwritesExistingArtifact() throws {
        let cache = BuildCache(projectRoot: tempRoot)
        try cache.write(Data("v1".utf8), for: "images", key: "k", ext: "bin")
        try cache.write(Data("v2".utf8), for: "images", key: "k", ext: "bin")
        let written = try Data(contentsOf: cache.path(for: "images", key: "k", ext: "bin"))
        XCTAssertEqual(String(data: written, encoding: .utf8), "v2")
    }

    func testExistsTreatsZeroByteFileAsCorruptAndReturnsFalse() throws {
        let cache = BuildCache(projectRoot: tempRoot)
        let url = cache.path(for: "images", key: "corrupt", ext: "bin")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: Data())
        XCTAssertFalse(cache.exists(for: "images", key: "corrupt", ext: "bin"))
    }
}
