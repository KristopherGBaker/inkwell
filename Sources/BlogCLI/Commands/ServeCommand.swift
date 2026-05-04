import ArgumentParser
import Foundation
import BlogCore
import BlogPreview

struct ServeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "serve", abstract: "Preview generated site")

    @Option(name: .long, help: "Port to serve on")
    var port: Int = 8000

    @Flag(name: .long, help: "Watch source files and reload the preview on changes")
    var watch = false

    mutating func run() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let pipeline = BuildPipeline()
        let outputDirectory: URL

        if watch {
            outputDirectory = try pipeline.run(in: root).outputDirectory
        } else {
            outputDirectory = pipeline.outputDirectory(in: root)
        }

        let server = PreviewServer(root: outputDirectory, port: port, liveReloadEnabled: watch)

        let watcher: PreviewWatcher?
        if watch {
            var watcherRef: PreviewWatcher?
            watcher = PreviewWatcher(
                paths: watchedPaths(root: root),
                excludedPaths: Self.watchedExclusions(root: root, outputDirectory: outputDirectory)
            ) {
                do {
                    let report = try pipeline.run(in: root)
                    watcherRef?.updateExcludedPaths(Self.watchedExclusions(root: root, outputDirectory: report.outputDirectory))
                    server.updateRoot(to: report.outputDirectory)
                    watcherRef?.refreshBaseline()
                    server.triggerReload()
                    print("Rebuilt preview")
                } catch {
                    fputs("Preview rebuild failed: \(error)\n", stderr)
                }
            }
            watcherRef = watcher
            watcher?.start()
        } else {
            watcher = nil
        }

        defer {
            watcher?.stop()
        }

        try server.start()
    }

    static func watchedPaths(root: URL) -> [URL] {
        [
            root.appendingPathComponent("content"),
            root.appendingPathComponent("data"),
            root.appendingPathComponent("themes"),
            root.appendingPathComponent("blog.config.json"),
            root.appendingPathComponent("public"),
            root.appendingPathComponent("static")
        ]
    }

    private func watchedPaths(root: URL) -> [URL] {
        Self.watchedPaths(root: root)
    }

    static func watchedExclusions(root: URL, outputDirectory: URL) -> [URL] {
        let publicRoot = root.appendingPathComponent("public").standardizedFileURL
        let outputDirectory = outputDirectory.standardizedFileURL

        guard outputDirectory.path.hasPrefix(publicRoot.path + "/") else {
            return []
        }

        return [outputDirectory]
    }
}
