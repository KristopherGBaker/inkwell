import ArgumentParser
import Foundation
import BlogPreview

struct ServeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "serve", abstract: "Preview generated site")

    @Option(name: .long, help: "Port to serve on")
    var port: Int = 8000

    mutating func run() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let docs = root.appendingPathComponent("docs")
        let server = PreviewServer(root: docs, port: port)
        try server.start()
    }
}
