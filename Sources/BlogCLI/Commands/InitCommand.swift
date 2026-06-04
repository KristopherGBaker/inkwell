import ArgumentParser
import Foundation

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "init", abstract: "Initialize a blog project")

    mutating func run() throws {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        try createScaffoldDirectories(fm: fm, at: cwd)
        try writeConfigAndTheme(at: cwd)
        try writeThemeAssets(at: cwd)
        try write(initGitignore, to: ".gitignore", in: cwd)
        print("Initialized blog project")
    }

    private func createScaffoldDirectories(fm: FileManager, at cwd: URL) throws {
        for relativePath in [
            "content/posts",
            "themes/default/templates",
            "themes/default/assets/css",
            "themes/default/assets/js",
            "public"
        ] {
            try fm.createDirectory(
                at: cwd.appendingPathComponent(relativePath),
                withIntermediateDirectories: true
            )
        }
    }

    private func writeConfigAndTheme(at cwd: URL) throws {
        try write(initConfigJSON, to: "blog.config.json", in: cwd)
        try write(initThemeManifest(), to: "themes/default/theme.json", in: cwd)
        try write(initLayoutHTML, to: "themes/default/templates/layout.html", in: cwd)
    }

    private func writeThemeAssets(at cwd: URL) throws {
        try write(initSearchScript, to: "themes/default/assets/js/search.js", in: cwd)
        try write(initPrismJS, to: "themes/default/assets/js/prism.js", in: cwd)
        try write(initPrismCSS, to: "themes/default/assets/css/prism.css", in: cwd)
        try defaultTailwindCSSData.write(
            to: cwd.appendingPathComponent("themes/default/assets/css/tailwind.css")
        )
    }

    /// Writes a UTF-8 string to `relativePath` under `cwd`.
    private func write(_ contents: String, to relativePath: String, in cwd: URL) throws {
        try contents.write(
            to: cwd.appendingPathComponent(relativePath),
            atomically: true,
            encoding: .utf8
        )
    }
}
