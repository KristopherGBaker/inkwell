import ArgumentParser
import Foundation

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "init", abstract: "Initialize a blog project")

    mutating func run() throws {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        try fm.createDirectory(at: cwd.appendingPathComponent("content/posts"), withIntermediateDirectories: true)
        try fm.createDirectory(at: cwd.appendingPathComponent("themes/default/templates"), withIntermediateDirectories: true)
        try fm.createDirectory(at: cwd.appendingPathComponent("themes/default/assets/css"), withIntermediateDirectories: true)
        try fm.createDirectory(at: cwd.appendingPathComponent("themes/default/assets/js"), withIntermediateDirectories: true)
        try fm.createDirectory(at: cwd.appendingPathComponent("public"), withIntermediateDirectories: true)

        let config = """
        {
          "title": "My Blog",
          "baseURL": "/",
          "theme": "default",
          "outputDir": "docs"
        }
        """
        try config.write(to: cwd.appendingPathComponent("blog.config.json"), atomically: true, encoding: .utf8)
        print("Initialized blog project")
    }
}
