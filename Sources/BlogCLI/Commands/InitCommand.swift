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

        let themeManifest = """
        {
          "name": "default",
          "version": "0.1.0",
          "compatibleCore": ">=0.1.0"
        }
        """
        try themeManifest.write(to: cwd.appendingPathComponent("themes/default/theme.json"), atomically: true, encoding: .utf8)

        let layout = """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>{{title}}</title>
          <link rel="stylesheet" href="/assets/css/prism.css">
        </head>
        <body>
          <main>{{content}}</main>
          <script defer src="/assets/js/prism.js"></script>
        </body>
        </html>
        """
        try layout.write(to: cwd.appendingPathComponent("themes/default/templates/layout.html"), atomically: true, encoding: .utf8)

        try "window.Prism = window.Prism || {};\n".write(to: cwd.appendingPathComponent("themes/default/assets/js/prism.js"), atomically: true, encoding: .utf8)
        try "pre[class*=\"language-\"]{background:#0f172a;color:#e2e8f0;padding:1rem;border-radius:8px;overflow-x:auto;}\n".write(to: cwd.appendingPathComponent("themes/default/assets/css/prism.css"), atomically: true, encoding: .utf8)
        print("Initialized blog project")
    }
}
