import ArgumentParser
import Foundation

struct PostCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "post",
        abstract: "Manage posts",
        subcommands: [PostNewCommand.self, PostListCommand.self]
    )
}

struct PostNewCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "new", abstract: "Create a new post")

    @Argument(help: "Post title")
    var title: String

    mutating func run() throws {
        let slug = slugify(title)
        let now = ISO8601DateFormatter().string(from: Date())
        let datePrefix = String(now.prefix(10))
        let fileName = "\(datePrefix)-\(slug).md"
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        let postDir = cwd.appendingPathComponent("content/posts")
        try fm.createDirectory(at: postDir, withIntermediateDirectories: true)
        let postPath = postDir.appendingPathComponent(fileName)

        let content = """
        ---
        title: \(title)
        date: \(now)
        slug: \(slug)
        draft: true
        ---

        Start writing here.
        """

        try content.write(to: postPath, atomically: true, encoding: .utf8)
        print(postPath.path)
    }
}

func slugify(_ title: String) -> String {
    title.lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}
