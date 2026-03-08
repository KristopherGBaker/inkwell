import ArgumentParser
import Foundation
import BlogCore

struct DeployCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "deploy",
        abstract: "Manage deployment setup",
        subcommands: [DeploySetupCommand.self]
    )
}

struct DeploySetupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "setup",
        abstract: "Generate optional hosting setup files",
        subcommands: [DeploySetupGitHubPagesCommand.self]
    )
}

struct DeploySetupGitHubPagesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "github-pages",
        abstract: "Generate a GitHub Pages workflow"
    )

    mutating func run() throws {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: fm.currentDirectoryPath)
        let outputDir = try loadOutputDirectory(at: root)
        let workflowDirectory = root.appendingPathComponent(".github/workflows")
        let workflowPath = workflowDirectory.appendingPathComponent("pages.yml")

        try fm.createDirectory(at: workflowDirectory, withIntermediateDirectories: true)
        try workflow(outputDir: outputDir).write(to: workflowPath, atomically: true, encoding: .utf8)

        print("Created GitHub Pages workflow at .github/workflows/pages.yml")
        print("Review blog.config.json baseURL and enable GitHub Pages in repository settings.")
    }

    private func loadOutputDirectory(at root: URL) throws -> String {
        let configPath = root.appendingPathComponent("blog.config.json")
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return "docs"
        }

        let data = try Data(contentsOf: configPath)
        let config = try JSONDecoder().decode(SiteConfig.self, from: data)
        return config.outputDir
    }

    private func workflow(outputDir: String) -> String {
        """
        name: Deploy to GitHub Pages

        on:
          push:
            branches: [main]
          workflow_dispatch:

        permissions:
          contents: read
          pages: write
          id-token: write

        concurrency:
          group: pages
          cancel-in-progress: true

        jobs:
          build:
            runs-on: macos-latest
            steps:
              - uses: actions/checkout@v4
              - uses: swift-actions/setup-swift@v2
              - name: Build site
                run: swift run inkwell build
              - uses: actions/upload-pages-artifact@v3
                with:
                  path: \(outputDir)

          deploy:
            environment:
              name: github-pages
              url: ${{ steps.deployment.outputs.page_url }}
            runs-on: ubuntu-latest
            needs: build
            steps:
              - id: deployment
                uses: actions/deploy-pages@v4
        """
    }
}
