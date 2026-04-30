import Foundation

public struct ProjectChecker {
    private let linkChecker: LinkChecker
    private let contentLoader: ContentLoader

    public init(linkChecker: LinkChecker = LinkChecker(), contentLoader: ContentLoader = ContentLoader()) {
        self.linkChecker = linkChecker
        self.contentLoader = contentLoader
    }

    public func check(projectRoot: URL) -> ProjectCheckResult {
        let configResult = loadSiteConfig(projectRoot: projectRoot)
        let brokenLinks = linkChecker.check(projectRoot: projectRoot, siteConfig: configResult.config).brokenLinks
        var errors: [String] = []
        var posts: [PostDocument] = []

        if let configError = configResult.error {
            errors.append(configError)
        }

        for postURL in contentLoader.postFileURLs(in: projectRoot) {
            do {
                let post = try contentLoader.loadPost(from: postURL)
                posts.append(post)
                try SchemaValidator.validate(frontMatter: post.frontMatter)

                if let coverImageError = missingCoverImageError(for: post, projectRoot: projectRoot) {
                    errors.append(coverImageError)
                }
            } catch let error as ContentLoaderError {
                errors.append(describe(contentLoaderError: error, projectRoot: projectRoot))
            } catch let error as SchemaValidatorError {
                errors.append("\(relativePath(for: postURL, root: projectRoot)): \(error.localizedDescription)")
            } catch {
                errors.append("\(relativePath(for: postURL, root: projectRoot)): \(error.localizedDescription)")
            }
        }

        if let collision = TaxonomySlugCollisionValidator.firstCollision(in: posts) {
            errors.append("Taxonomy slug collision for \(collision.kind) '\(collision.slug)': \(collision.labels.joined(separator: ", "))")
        }

        // Collection items: validate asset-shaped front-matter fields.
        if let configs = configResult.config.collections, configs.isEmpty == false {
            do {
                let collections = try contentLoader.loadCollections(configs, in: projectRoot)
                for (_, collection) in collections {
                    for item in collection.items {
                        errors.append(contentsOf: assetErrors(in: item.frontMatter, source: item.sourcePath, projectRoot: projectRoot))
                    }
                }
            } catch let error as ContentLoaderError {
                errors.append(describe(contentLoaderError: error, projectRoot: projectRoot))
            } catch {
                errors.append("collections: \(error.localizedDescription)")
            }
        }

        return ProjectCheckResult(
            brokenLinks: brokenLinks,
            errors: errors.sorted()
        )
    }

    private func loadSiteConfig(projectRoot: URL) -> (config: SiteConfig, error: String?) {
        let configURL = projectRoot.appendingPathComponent("blog.config.json")
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return (SiteConfig(title: "Blog"), nil)
        }

        do {
            let data = try Data(contentsOf: configURL)
            return (try JSONDecoder().decode(SiteConfig.self, from: data), nil)
        } catch {
            return (SiteConfig(title: "Blog"), "blog.config.json: \(error.localizedDescription)")
        }
    }

    private func missingCoverImageError(for post: PostDocument, projectRoot: URL) -> String? {
        guard let coverImage = post.frontMatter.coverImage?.trimmingCharacters(in: .whitespacesAndNewlines), !coverImage.isEmpty else {
            return nil
        }

        if coverImage.hasPrefix("http://") || coverImage.hasPrefix("https://") || coverImage.hasPrefix("//") {
            return nil
        }

        let assetURL: URL
        if coverImage.hasPrefix("/") {
            assetURL = projectRoot
                .appendingPathComponent("public")
                .appendingPathComponent(String(coverImage.drop(while: { $0 == "/" })))
        } else {
            assetURL = post.sourcePath.deletingLastPathComponent().appendingPathComponent(coverImage)
        }

        guard !FileManager.default.fileExists(atPath: assetURL.path) else {
            return nil
        }

        return "\(relativePath(for: post.sourcePath, root: projectRoot)): Missing cover image: \(coverImage)"
    }

    private func describe(contentLoaderError: ContentLoaderError, projectRoot: URL) -> String {
        switch contentLoaderError {
        case let .malformedFrontMatter(url):
            return "\(relativePath(for: url, root: projectRoot)): Malformed front matter"
        case let .invalidFrontMatter(url, description):
            return "\(relativePath(for: url, root: projectRoot)): Invalid front matter: \(description)"
        case let .unknownCollection(id):
            return "Unknown collection: \(id)"
        }
    }

    private static let assetFieldNames: Set<String> = [
        "coverImage", "shots", "featuredImage", "ogImage", "thumbnail"
    ]

    private func assetErrors(in frontMatter: [String: Any], source: URL, projectRoot: URL) -> [String] {
        var errors: [String] = []
        for (key, value) in frontMatter where Self.assetFieldNames.contains(key) {
            for path in extractAssetPaths(from: value) {
                if let error = validateAssetPath(path, field: key, source: source, projectRoot: projectRoot) {
                    errors.append(error)
                }
            }
        }
        return errors
    }

    private func extractAssetPaths(from value: Any) -> [String] {
        if let string = value as? String { return [string] }
        if let array = value as? [String] { return array }
        if let array = value as? [Any] { return array.compactMap { $0 as? String } }
        return []
    }

    private func validateAssetPath(_ raw: String, field: String, source: URL, projectRoot: URL) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("//") {
            return nil
        }
        if trimmed.hasPrefix("/") == false {
            return "\(relativePath(for: source, root: projectRoot)): \(field) has relative asset path \"\(trimmed)\" — use \"/assets/...\" or a fully-qualified URL"
        }
        if trimmed.hasPrefix("/assets/") {
            let suffix = String(trimmed.dropFirst("/assets/".count))
            let staticURL = projectRoot.appendingPathComponent("static/assets").appendingPathComponent(suffix)
            let publicURL = projectRoot.appendingPathComponent("public/assets").appendingPathComponent(suffix)
            if FileManager.default.fileExists(atPath: staticURL.path) || FileManager.default.fileExists(atPath: publicURL.path) {
                return nil
            }
            return "\(relativePath(for: source, root: projectRoot)): \(field) references missing asset \(trimmed)"
        }
        // Other root-absolute paths: resolve under public/ for legacy compat.
        let legacy = projectRoot.appendingPathComponent("public").appendingPathComponent(String(trimmed.drop(while: { $0 == "/" })))
        if FileManager.default.fileExists(atPath: legacy.path) {
            return nil
        }
        return "\(relativePath(for: source, root: projectRoot)): \(field) references missing asset \(trimmed)"
    }

    private func relativePath(for url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path

        guard filePath.hasPrefix(rootPath + "/") else {
            return url.lastPathComponent
        }

        return String(filePath.dropFirst(rootPath.count + 1))
    }
}
