import Foundation
import Yams

public enum ContentLoaderError: Error {
    case malformedFrontMatter(URL)
    case invalidFrontMatter(URL, String)
    case unknownCollection(String)
}

public struct ContentLoader {
    public init() {}

    // MARK: - Posts (legacy / backward-compatible)

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
        let frontMatter = try parseTypedFrontMatter(frontMatterBlock, source: url)
        return PostDocument(frontMatter: frontMatter, body: body, sourcePath: url)
    }

    private func parseTypedFrontMatter(_ block: String, source: URL) throws -> PostFrontMatter {
        do {
            return try YAMLDecoder().decode(PostFrontMatter.self, from: block)
        } catch {
            throw ContentLoaderError.invalidFrontMatter(source, String(describing: error))
        }
    }

    // MARK: - Generic collections

    /// Loads each declared collection from disk. The returned dictionary is
    /// keyed by `CollectionConfig.id`, with items pre-sorted per the
    /// collection's `sortBy` / `sortOrder` and drafts dropped.
    public func loadCollections(_ configs: [CollectionConfig], in projectRoot: URL) throws -> [String: Collection] {
        var result: [String: Collection] = [:]
        for config in configs {
            let dir = projectRoot.appendingPathComponent(config.dir)
            let urls = collectionFileURLs(at: dir)
            let items = try urls.compactMap { try loadCollectionItem(from: $0) }
            let visible = items.filter { $0.draft != true }
            let sorted = sortItems(visible, sortBy: config.resolvedSortBy, order: config.resolvedSortOrder)
            result[config.id] = Collection(config: config, items: sorted)
        }
        return result
    }

    private func collectionFileURLs(at directory: URL) -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "md" }
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
    }

    private func loadCollectionItem(from url: URL) throws -> CollectionItem? {
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

        let dict: [String: Any]
        do {
            let loaded = try Yams.load(yaml: frontMatterBlock)
            dict = (loaded as? [String: Any]) ?? [:]
        } catch {
            throw ContentLoaderError.invalidFrontMatter(url, String(describing: error))
        }

        guard
            let slug = dict["slug"] as? String,
            let title = dict["title"] as? String
        else {
            return nil
        }

        return CollectionItem(
            slug: slug,
            title: title,
            date: stringValue(dict["date"]),
            summary: dict["summary"] as? String,
            tags: stringArray(dict["tags"]),
            categories: stringArray(dict["categories"]),
            draft: dict["draft"] as? Bool,
            series: dict["series"] as? String,
            canonicalUrl: dict["canonicalUrl"] as? String,
            coverImage: dict["coverImage"] as? String,
            frontMatter: dict,
            body: body,
            sourcePath: url
        )
    }

    private func sortItems(_ items: [CollectionItem], sortBy: String, order: String) -> [CollectionItem] {
        let sorted = items.sorted { lhs, rhs in
            let leftKey = comparableSortKey(for: lhs, sortBy: sortBy)
            let rightKey = comparableSortKey(for: rhs, sortBy: sortBy)
            return leftKey < rightKey
        }
        return order.lowercased() == "asc" ? sorted : sorted.reversed()
    }

    private func comparableSortKey(for item: CollectionItem, sortBy: String) -> String {
        switch sortBy {
        case "date":
            return item.date ?? ""
        default:
            if let value = item.frontMatter[sortBy] {
                return Self.normalizeSortKey(value)
            }
            return ""
        }
    }

    private static func normalizeSortKey(_ value: Any) -> String {
        if let string = value as? String { return string }
        if let int = value as? Int { return String(format: "%020d", int) }
        if let double = value as? Double { return String(format: "%030.10f", double) }
        return String(describing: value)
    }

    private func stringValue(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        if let int = value as? Int { return String(int) }
        if let date = value as? Date {
            let formatter = ISO8601DateFormatter()
            return formatter.string(from: date)
        }
        return nil
    }

    private func stringArray(_ value: Any?) -> [String]? {
        if let array = value as? [String] { return array }
        if let raw = value as? [Any] {
            return raw.compactMap { $0 as? String }
        }
        return nil
    }
}
