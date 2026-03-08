import Foundation
import XCTest
@testable import BlogCLI

final class DeployCommandTests: XCTestCase {
    func testDeployCommandIsRegistered() {
        let subcommands = BlogCommand.configuration.subcommands
        XCTAssertTrue(subcommands.contains { $0 == DeployCommand.self })
    }

    func testGitHubPagesSetupCreatesWorkflowUsingConfiguredOutputDir() throws {
        let fm = FileManager.default
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)

        let config = """
        {
          "title": "My Blog",
          "baseURL": "/docs-site/",
          "theme": "default",
          "outputDir": "public-site"
        }
        """
        let configPath = temp.appendingPathComponent("blog.config.json")
        try config.write(to: configPath, atomically: true, encoding: .utf8)

        let old = fm.currentDirectoryPath
        _ = fm.changeCurrentDirectoryPath(temp.path)
        defer { _ = fm.changeCurrentDirectoryPath(old) }

        var command = DeploySetupGitHubPagesCommand()
        try command.run()

        let workflowPath = temp.appendingPathComponent(".github/workflows/pages.yml")
        XCTAssertTrue(fm.fileExists(atPath: workflowPath.path))

        let workflow = try String(contentsOf: workflowPath, encoding: .utf8)
        XCTAssertTrue(workflow.contains("path: public-site"))

        let updatedConfig = try String(contentsOf: configPath, encoding: .utf8)
        XCTAssertEqual(updatedConfig, config)
    }
}
