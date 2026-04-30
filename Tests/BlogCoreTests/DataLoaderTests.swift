import Foundation
import XCTest
@testable import BlogCore

final class DataLoaderTests: XCTestCase {
    func testLoadsYamlAndJsonFilesIntoNamespace() throws {
        let root = makeTempProject()
        try writeFile(root, "data/experience.yml", """
        - org: Wolt
          role: Senior Engineer
          years: "2023 — Now"
        """)
        try writeFile(root, "data/site.json", """
        { "tagline": "Hello world" }
        """)

        let data = try DataLoader().load(in: root)
        let experience = try XCTUnwrap(data["experience"] as? [[String: Any]])
        XCTAssertEqual(experience.first?["org"] as? String, "Wolt")
        XCTAssertEqual(experience.first?["role"] as? String, "Senior Engineer")
        let site = try XCTUnwrap(data["site"] as? [String: Any])
        XCTAssertEqual(site["tagline"] as? String, "Hello world")
    }

    func testReturnsEmptyDictWhenDataDirAbsent() throws {
        let root = makeTempProject()
        let data = try DataLoader().load(in: root)
        XCTAssertTrue(data.isEmpty)
    }

    func testIgnoresUnsupportedExtensions() throws {
        let root = makeTempProject()
        try writeFile(root, "data/notes.txt", "hello")
        try writeFile(root, "data/site.json", "{\"a\":1}")
        let data = try DataLoader().load(in: root)
        XCTAssertNil(data["notes"])
        XCTAssertNotNil(data["site"])
    }

    func testReportsDecodeErrorWithFileName() throws {
        let root = makeTempProject()
        try writeFile(root, "data/broken.yml", "key: [unclosed\n")
        XCTAssertThrowsError(try DataLoader().load(in: root)) { error in
            guard let dataError = error as? DataLoaderError else {
                XCTFail("Expected DataLoaderError, got \(error)")
                return
            }
            switch dataError {
            case .decodeFailed(let url, _):
                XCTAssertEqual(url.lastPathComponent, "broken.yml")
            }
        }
    }

    func testBuildPipelineExposesDataInTemplateContext() throws {
        let root = try makeTempBlogProject()
        try writeFile(root, "data/site.yml", "tagline: From data file\n")

        // Add a project-side template that reads the data namespace and emits a marker.
        let layoutsDir = root.appendingPathComponent("themes/default/templates/layouts")
        try FileManager.default.createDirectory(at: layoutsDir, withIntermediateDirectories: true)
        try "DATA-TAGLINE:{{ data.site.tagline }}".write(
            to: layoutsDir.appendingPathComponent("landing.html"),
            atomically: true,
            encoding: .utf8
        )

        _ = try BuildPipeline().run(in: root)

        let html = try String(contentsOf: root.appendingPathComponent("docs/index.html"))
        XCTAssertTrue(html.contains("DATA-TAGLINE:From data file"), "Expected data file value to flow into template context, got:\n\(html)")
    }

    private func makeTempProject() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeFile(_ root: URL, _ relative: String, _ content: String) throws {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
