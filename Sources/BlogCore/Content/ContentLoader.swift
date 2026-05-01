import Foundation
import Yams

public enum ContentLoaderError: Error {
    case malformedFrontMatter(URL)
    case invalidFrontMatter(URL, String)
    case unknownCollection(String)
}

// swiftlint:disable:next type_body_length
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
        let parsed = try Self.splitFrontMatter(raw, source: url)
        let frontMatter = try parseTypedFrontMatter(parsed.frontMatter, source: url)
        return PostDocument(frontMatter: frontMatter, body: parsed.body, sourcePath: url)
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
    ///
    /// `defaultLanguage` is the site's default language tag (used for files
    /// without a `.<lang>.md` suffix). `configuredLanguages` lists every
    /// language the site supports — files with a recognized suffix that
    /// isn't in this list are skipped.
    public func loadCollections(
        _ configs: [CollectionConfig],
        in projectRoot: URL,
        defaultLanguage: String = "en",
        configuredLanguages: [String]? = nil
    ) throws -> [String: Collection] {
        let langs = configuredLanguages ?? [defaultLanguage]
        var result: [String: Collection] = [:]
        for config in configs {
            let dir = projectRoot.appendingPathComponent(config.dir)
            let urls = collectionFileURLs(at: dir)
            var items: [CollectionItem] = []
            for url in urls {
                let suffix = Self.parseLanguageSuffix(from: url.lastPathComponent)
                let lang = suffix ?? defaultLanguage
                if let suffix, langs.contains(suffix) == false { continue }
                if let item = try loadCollectionItem(from: url, lang: lang) {
                    items.append(item)
                }
            }
            let visible = items.filter { $0.draft != true }
            let paired = pairTranslations(visible)
            let sorted = sortItems(paired, sortBy: config.resolvedSortBy, order: config.resolvedSortOrder)
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

    /// Pairs items sharing the same `slug` and stamps each with the full set
    /// of available languages.
    private func pairTranslations(_ items: [CollectionItem]) -> [CollectionItem] {
        var bySlug: [String: [String]] = [:]
        for item in items {
            bySlug[item.slug, default: []].append(item.lang)
        }
        return items.map { item in
            var copy = item
            copy.availableLanguages = (bySlug[item.slug] ?? [item.lang]).sorted()
            return copy
        }
    }

    /// Returns the BCP-47 language tag if `filename` ends in
    /// `.<lang>.md`, otherwise nil. Recognizes 2-3 letter primary tags
    /// optionally followed by a region (e.g. `en`, `ja`, `en-US`).
    public static func parseLanguageSuffix(from filename: String) -> String? {
        guard filename.hasSuffix(".md") else { return nil }
        let withoutExt = String(filename.dropLast(3))
        guard let dot = withoutExt.lastIndex(of: ".") else { return nil }
        let candidate = String(withoutExt[withoutExt.index(after: dot)...])
        return isLanguageTag(candidate) ? candidate : nil
    }

    /// Returns the basename (everything before the optional `.<lang>` and
    /// before the `.md` extension).
    public static func basename(stripping filename: String) -> String {
        guard filename.hasSuffix(".md") else { return filename }
        let withoutExt = String(filename.dropLast(3))
        if let dot = withoutExt.lastIndex(of: ".") {
            let candidate = String(withoutExt[withoutExt.index(after: dot)...])
            if isLanguageTag(candidate) {
                return String(withoutExt[..<dot])
            }
        }
        return withoutExt
    }

    private static func isLanguageTag(_ value: String) -> Bool {
        // Primary tag: 2 or 3 lowercase letters. Optional region: hyphen + 2 uppercase letters.
        let parts = value.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let primary = parts[0]
        guard (2...3).contains(primary.count), primary.allSatisfy({ $0.isLetter && $0.isLowercase }) else {
            return false
        }
        if parts.count == 2 {
            let region = parts[1]
            guard region.count == 2, region.allSatisfy({ $0.isLetter && $0.isUppercase }) else {
                return false
            }
        }
        return true
    }

    private func loadCollectionItem(from url: URL, lang: String = "en") throws -> CollectionItem? {
        let raw = try String(contentsOf: url)
        let parsed = try Self.splitFrontMatter(raw, source: url)
        let frontMatterBlock = parsed.frontMatter
        let body = parsed.body

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
            sourcePath: url,
            lang: lang,
            availableLanguages: [lang]
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

    // MARK: - Standalone pages

    /// Walks `content/pages/` and returns one `Page` per Markdown file.
    /// Routes are derived from the relative path: `about.md` → `/about/`,
    /// `now/index.md` → `/now/`, `projects/wolt.md` → `/projects/wolt/`.
    /// Pages with a `<basename>.<lang>.md` suffix translate the equivalent
    /// non-suffixed page; their canonical `route` strips the suffix.
    public func loadPages(
        in projectRoot: URL,
        defaultLanguage: String = "en",
        configuredLanguages: [String]? = nil
    ) throws -> [Page] {
        let langs = configuredLanguages ?? [defaultLanguage]
        let pagesDir = projectRoot.appendingPathComponent("content/pages")
        guard FileManager.default.fileExists(atPath: pagesDir.path) else { return [] }

        var pages: [Page] = []
        let pagesPath = pagesDir.standardizedFileURL.path
        guard let enumerator = FileManager.default.enumerator(
            at: pagesDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for case let url as URL in enumerator {
            guard url.pathExtension == "md" else { continue }
            let standardized = url.standardizedFileURL.path
            guard standardized.hasPrefix(pagesPath) else { continue }
            var relative = String(standardized.dropFirst(pagesPath.count))
            if relative.hasPrefix("/") { relative = String(relative.dropFirst()) }

            let suffix = Self.parseLanguageSuffix(from: url.lastPathComponent)
            let lang = suffix ?? defaultLanguage
            if let suffix, langs.contains(suffix) == false { continue }

            // Strip the language suffix from the filename so the canonical
            // route matches the default-language equivalent.
            let canonicalRelative: String
            if suffix != nil {
                let dir = (relative as NSString).deletingLastPathComponent
                let stripped = Self.basename(stripping: url.lastPathComponent) + ".md"
                canonicalRelative = dir.isEmpty ? stripped : "\(dir)/\(stripped)"
            } else {
                canonicalRelative = relative
            }

            let route = Self.pageRoute(fromRelativePath: canonicalRelative)

            let raw = try String(contentsOf: url)
            let parsed = try Self.splitFrontMatter(raw, source: url)
            let frontMatterBlock = parsed.frontMatter
            let body = parsed.body

            let dict: [String: Any]
            do {
                dict = (try Yams.load(yaml: frontMatterBlock) as? [String: Any]) ?? [:]
            } catch {
                throw ContentLoaderError.invalidFrontMatter(url, String(describing: error))
            }

            let layout = (dict["layout"] as? String) ?? "page"
            pages.append(Page(
                route: route,
                layout: layout,
                title: dict["title"] as? String,
                summary: dict["summary"] as? String,
                frontMatter: dict,
                body: body,
                sourcePath: url,
                lang: lang,
                availableLanguages: [lang]
            ))
        }

        // Pair pages with the same canonical route across languages.
        var langsByRoute: [String: [String]] = [:]
        for page in pages {
            langsByRoute[page.route, default: []].append(page.lang)
        }
        let paired = pages.map { page -> Page in
            var copy = page
            copy.availableLanguages = (langsByRoute[page.route] ?? [page.lang]).sorted()
            return copy
        }

        return paired.sorted { ($0.route, $0.lang) < ($1.route, $1.lang) }
    }

    /// Splits a Markdown file's `---\n…\n---\n?` front matter block from its
    /// body. Tolerates files that end at the closing `---` with no trailing
    /// newline (i.e. empty body), and files where the closing `---` is on
    /// the very last line.
    static func splitFrontMatter(_ raw: String, source: URL) throws -> (frontMatter: String, body: String) {
        guard raw.hasPrefix("---\n") else {
            throw ContentLoaderError.malformedFrontMatter(source)
        }
        let rest = String(raw.dropFirst(4))

        if let closing = rest.range(of: "\n---\n") {
            let fm = String(rest[..<closing.lowerBound])
            let body = String(rest[closing.upperBound...])
            return (fm, body)
        }

        if rest.hasSuffix("\n---") {
            let fm = String(rest.dropLast(4))
            return (fm, "")
        }

        throw ContentLoaderError.malformedFrontMatter(source)
    }

    static func pageRoute(fromRelativePath relativePath: String) -> String {
        var path = relativePath
        if path.hasSuffix(".md") { path = String(path.dropLast(3)) }
        if path.hasSuffix("/index") {
            path = String(path.dropLast("/index".count))
        } else if path == "index" {
            path = ""
        }
        if path.isEmpty { return "/" }
        return "/\(path)/"
    }
}
