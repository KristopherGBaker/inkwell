import ArgumentParser
import Foundation
import BlogCore

struct ContentCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "content",
        abstract: "Manage collection content (posts, projects, etc.)",
        subcommands: [ContentNewCommand.self]
    )
}

struct ContentNewCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "new",
        abstract: "Scaffold a new content item in a collection"
    )

    @Argument(help: "Collection id (must match an entry in blog.config.json's collections array)")
    var collection: String

    @Argument(help: "Content title")
    var title: String

    mutating func run() throws {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        let path = try Self.scaffold(root: cwd, collectionId: collection, title: title)
        print(path.path)
    }

    /// Test-friendly entry point. Resolves the collection from `blog.config.json`,
    /// derives a sensible scaffold based on `sortBy` (date- vs year-shaped), and
    /// writes the new file. Returns the URL of the created file.
    @discardableResult
    static func scaffold(root: URL, collectionId: String, title: String) throws -> URL {
        let configURL = root.appendingPathComponent("blog.config.json")
        let configData = try Data(contentsOf: configURL)
        let config = try JSONDecoder().decode(SiteConfig.self, from: configData)
        guard let collectionConfig = config.collections?.first(where: { $0.id == collectionId }) else {
            throw ValidationError("Unknown collection '\(collectionId)'. Add it to collections in blog.config.json first.")
        }

        let slug = slugify(title)
        let dir = root.appendingPathComponent(collectionConfig.dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let scaffoldText = scaffoldText(for: collectionConfig, title: title, slug: slug)
        let fileName: String
        switch collectionConfig.resolvedSortBy {
        case "date":
            let now = ISO8601DateFormatter().string(from: Date())
            let datePrefix = String(now.prefix(10))
            fileName = "\(datePrefix)-\(slug).md"
        default:
            fileName = "\(slug).md"
        }

        let target = dir.appendingPathComponent(fileName)
        try scaffoldText.write(to: target, atomically: true, encoding: .utf8)
        return target
    }

    private static func scaffoldText(for config: CollectionConfig, title: String, slug: String) -> String {
        switch config.resolvedSortBy {
        case "date":
            let now = ISO8601DateFormatter().string(from: Date())
            return """
            ---
            title: \(title)
            date: \(now)
            slug: \(slug)
            draft: true
            ---

            Start writing here.
            """
        case "year":
            let calendar = Calendar(identifier: .gregorian)
            let year = calendar.component(.year, from: Date())
            return """
            ---
            title: \(title)
            slug: \(slug)
            year: \(year)
            summary:
            tags: []
            ---

            Start writing here.
            """
        default:
            return """
            ---
            title: \(title)
            slug: \(slug)
            ---

            Start writing here.
            """
        }
    }
}
