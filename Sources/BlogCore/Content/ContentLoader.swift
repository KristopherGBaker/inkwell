import Foundation

public enum ContentLoaderError: Error {
    case malformedFrontMatter(URL)
}

public struct ContentLoader {
    public init() {}

    public func loadPosts(in projectRoot: URL) throws -> [PostDocument] {
        let postsDir = projectRoot.appendingPathComponent("content/posts")
        guard let files = try? FileManager.default.contentsOfDirectory(at: postsDir, includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension == "md" }) else {
            return []
        }

        return try files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).map(loadPost)
    }

    private func loadPost(from url: URL) throws -> PostDocument {
        let raw = try String(contentsOf: url)
        let parts = raw.components(separatedBy: "\n---\n")
        guard parts.count >= 2, raw.hasPrefix("---\n") else {
            throw ContentLoaderError.malformedFrontMatter(url)
        }

        let frontMatterBlock = String(parts[0].dropFirst(4))
        let body = parts.dropFirst().joined(separator: "\n---\n")
        let frontMatter = parseFrontMatter(frontMatterBlock)
        return PostDocument(frontMatter: frontMatter, body: body, sourcePath: url)
    }

    private func parseFrontMatter(_ block: String) -> PostFrontMatter {
        var map: [String: String] = [:]
        for line in block.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                map[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }

        return PostFrontMatter(
            title: map["title"],
            date: map["date"],
            slug: map["slug"],
            summary: map["summary"],
            tags: nil,
            categories: nil,
            draft: map["draft"] == "true",
            series: map["series"],
            canonicalUrl: map["canonicalUrl"],
            coverImage: map["coverImage"]
        )
    }
}
