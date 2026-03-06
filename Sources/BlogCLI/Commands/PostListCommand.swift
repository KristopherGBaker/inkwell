import ArgumentParser
import Foundation

struct PostListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List posts")

    @Flag(name: .long, help: "Print output as JSON")
    var json = false

    mutating func run() throws {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        let postsDir = cwd.appendingPathComponent("content/posts")
        let files = (try? fm.contentsOfDirectory(atPath: postsDir.path).filter { $0.hasSuffix(".md") }.sorted()) ?? []

        if json {
            let data = try JSONEncoder().encode(files)
            guard let output = String(data: data, encoding: .utf8) else {
                throw ValidationError("Could not encode post list as UTF-8")
            }
            print(output)
        } else {
            for file in files { print(file) }
        }
    }
}
