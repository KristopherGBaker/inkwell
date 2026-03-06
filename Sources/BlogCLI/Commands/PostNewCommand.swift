import ArgumentParser
import Foundation

struct PostCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "post",
        abstract: "Manage posts",
        subcommands: [PostNewCommand.self, PostListCommand.self, PostPublishCommand.self]
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

struct PostPublishCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "publish", abstract: "Mark a post as published")

    @Argument(help: "Post slug")
    var slug: String

    mutating func run() throws {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        let postsDir = cwd.appendingPathComponent("content/posts")
        let files = (try? fm.contentsOfDirectory(at: postsDir, includingPropertiesForKeys: nil)) ?? []
        guard let match = try files.first(where: { try file($0, hasSlug: slug) }) else {
            throw ValidationError("Could not find post with slug '\(slug)'")
        }

        let content = try String(contentsOf: match)
        let updated = updateDraftFlag(in: content)
        try updated.write(to: match, atomically: true, encoding: .utf8)
        print("Published \(slug)")
    }

    private func file(_ url: URL, hasSlug slug: String) throws -> Bool {
        guard url.pathExtension == "md" else { return false }
        let content = try String(contentsOf: url)
        return content.contains("\nslug: \(slug)\n")
    }

    private func updateDraftFlag(in markdown: String) -> String {
        if markdown.contains("\ndraft: true\n") {
            return markdown.replacingOccurrences(of: "\ndraft: true\n", with: "\ndraft: false\n")
        }
        if markdown.contains("\ndraft: false\n") {
            return markdown
        }
        if let range = markdown.range(of: "\n---\n", options: [], range: markdown.index(markdown.startIndex, offsetBy: 4)..<markdown.endIndex) {
            var copy = markdown
            copy.insert(contentsOf: "\ndraft: false", at: range.lowerBound)
            return copy
        }
        return markdown
    }
}

func slugify(_ title: String) -> String {
    title.lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}
