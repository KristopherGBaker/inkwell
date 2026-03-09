import Foundation
import Yams

public enum ContentLoaderError: Error {
    case malformedFrontMatter(URL)
    case invalidFrontMatter(URL, String)
}

public struct ContentLoader {
    public init() {}

    public func loadPosts(in projectRoot: URL) throws -> [PostDocument] {
        try postFileURLs(in: projectRoot).map(loadPost)
    }

    func postFileURLs(in projectRoot: URL) -> [URL] {
        let postsDir = projectRoot.appendingPathComponent("content/posts")
        guard let files = try? FileManager.default.contentsOfDirectory(at: postsDir, includingPropertiesForKeys: nil) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "md" }
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
    }

    func loadPost(from url: URL) throws -> PostDocument {
        let raw = try String(contentsOf: url)
        guard raw.hasPrefix("---\n") else {
            throw ContentLoaderError.malformedFrontMatter(url)
        }

        let rest = String(raw.dropFirst(4))
        guard let closingRange = rest.range(of: "\n---\n") else {
            throw ContentLoaderError.malformedFrontMatter(url)
        }

        let frontMatterBlock = String(rest[..<closingRange.lowerBound])
        let body = String(rest[closingRange.upperBound...])
        let frontMatter = try parseFrontMatter(frontMatterBlock, source: url)
        return PostDocument(frontMatter: frontMatter, body: body, sourcePath: url)
    }

    private func parseFrontMatter(_ block: String, source: URL) throws -> PostFrontMatter {
        do {
            return try YAMLDecoder().decode(PostFrontMatter.self, from: block)
        } catch {
            throw ContentLoaderError.invalidFrontMatter(source, String(describing: error))
        }
    }
}
