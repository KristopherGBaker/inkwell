import Foundation
import BlogPlugins
import BlogRenderer
import BlogThemes

public struct BuildReport {
    public let outputDirectory: URL
    public let routes: [String]
    public let errors: [String]

    public init(outputDirectory: URL, routes: [String], errors: [String]) {
        self.outputDirectory = outputDirectory
        self.routes = routes
        self.errors = errors
    }
}

public enum BuildPipelineError: Error, Equatable {
    case searchIndexEncodingFailed
    case taxonomySlugCollision(kind: String, slug: String, labels: [String])
}

public struct BuildPipeline {
    private let loader: ContentLoader
    private let dataLoader: DataLoader
    private let renderer: MarkdownRenderer
    private let pageContextBuilder: PageContextBuilder
    private let writer: OutputWriter
    private let plugins: PluginManager
    private let themes: ThemeManager

    public init(
        loader: ContentLoader = ContentLoader(),
        dataLoader: DataLoader = DataLoader(),
        renderer: MarkdownRenderer = MarkdownRenderer(),
        pageContextBuilder: PageContextBuilder = PageContextBuilder(),
        writer: OutputWriter = OutputWriter(),
        plugins: PluginManager = PluginManager(),
        themes: ThemeManager = ThemeManager()
    ) {
        self.loader = loader
        self.dataLoader = dataLoader
        self.renderer = renderer
        self.pageContextBuilder = pageContextBuilder
        self.writer = writer
        self.plugins = plugins
        self.themes = themes
    }

    public func run(in projectRoot: URL) throws -> BuildReport {
        let siteConfig = loadSiteConfig(projectRoot: projectRoot)
        let outputRoot = projectRoot.appendingPathComponent(siteConfig.outputDir)
        let urlBuilder = SiteURLBuilder(baseURL: siteConfig.baseURL)
        let pictureRewriter = PictureRewriter(projectRoot: projectRoot)
        let coverImageResolver = ResponsiveImageResolver(projectRoot: projectRoot)
        var pictureVariantsUsed: Set<String> = []
        let posts = try loader.loadPosts(in: projectRoot)
        var rendered: [String: String] = [:]

        for post in posts {
            try SchemaValidator.validate(frontMatter: post.frontMatter)
            try plugins.runBeforeParse(contentPath: post.sourcePath.path)
            guard let slug = post.frontMatter.slug else { continue }
            let html = try renderer.render(post.body)
            try plugins.runAfterParse(contentDocument: PluginDocument(slug: slug, content: post.body))
            let rewriteResult = pictureRewriter.rewrite(html: html)
            pictureVariantsUsed.formUnion(rewriteResult.usedVariantFilenames)
            rendered[slug] = rewriteResult.html
        }

        try validateTaxonomySlugUniqueness(posts: posts)

        let defaultLanguage = siteConfig.i18n?.resolvedDefaultLanguage ?? "en"
        let configuredLanguages = siteConfig.i18n?.resolvedLanguages ?? [defaultLanguage]

        // Per-language data dicts. Files without a language suffix back-fill
        // every language; suffixed files override only their own language.
        var dataByLang: [String: [String: Any]] = [:]
        for lang in configuredLanguages {
            dataByLang[lang] = try dataLoader.load(in: projectRoot, lang: lang)
        }

        var collections: [String: Collection] = [:]
        var collectionRendered: [String: [String: [String: String]]] = [:]
        if let configs = siteConfig.collections, configs.isEmpty == false {
            collections = try loader.loadCollections(
                configs,
                in: projectRoot,
                defaultLanguage: defaultLanguage,
                configuredLanguages: configuredLanguages
            )
            for (id, collection) in collections {
                var perLang: [String: [String: String]] = [:]
                let raw = collection.config.route
                let collectionRoute: String = {
                    var route = raw
                    if route.hasPrefix("/") == false { route = "/" + route }
                    if route.hasSuffix("/") == false { route += "/" }
                    return route
                }()
                for item in collection.items {
                    let html = try renderer.render(item.body)
                    let canonicalBase = "\(collectionRoute)\(item.slug)/"
                    let withAssets = AssetURLRewriter.rewriteRelativeURLs(in: html, base: canonicalBase)
                    let rewriteResult = pictureRewriter.rewrite(html: withAssets)
                    pictureVariantsUsed.formUnion(rewriteResult.usedVariantFilenames)
                    perLang[item.lang, default: [:]][item.slug] = rewriteResult.html
                }
                collectionRendered[id] = perLang
            }
        }

        let pages = try loader.loadPages(
            in: projectRoot,
            defaultLanguage: defaultLanguage,
            configuredLanguages: configuredLanguages
        )
        var pageRendered: [String: [String: String]] = [:]
        for page in pages {
            let html = try renderer.render(page.body)
            let withAssets = AssetURLRewriter.rewriteRelativeURLs(in: html, base: page.route)
            let rewriteResult = pictureRewriter.rewrite(html: withAssets)
            pictureVariantsUsed.formUnion(rewriteResult.usedVariantFilenames)
            pageRendered[page.lang, default: [:]][page.route] = rewriteResult.html
        }

        let coverImageClosure: FrontMatterImageResolver = { path, alt in
            coverImageResolver.resolve(path: path, alt: alt)?.contextDict()
        }
        let resolvingBuilder = PageContextBuilder(imageResolver: coverImageClosure)
        let plans = resolvingBuilder.buildPlans(
            posts: posts,
            renderedContent: rendered,
            baseURL: urlBuilder.baseURL,
            siteConfig: siteConfig,
            dataByLanguage: dataByLang,
            collections: collections,
            collectionRenderedContent: collectionRendered,
            pages: pages,
            pageRenderedContent: pageRendered
        )
        pictureVariantsUsed.formUnion(coverImageResolver.usedVariantFilenames)
        let templateRenderer = try TemplateRenderer(theme: siteConfig.theme, projectRoot: projectRoot)
        var builtPages = try plans.map { plan in
            BuiltPage(route: plan.route, html: try templateRenderer.render(template: plan.template, context: plan.context))
        }
        let extraHead = loadExtraHead(projectRoot: projectRoot, siteConfig: siteConfig)
        builtPages = builtPages.map { BuiltPage(route: $0.route, html: themes.injectHeadAssets(into: $0.html, baseURL: siteConfig.baseURL, extraHead: extraHead, theme: siteConfig.theme)) }

        for page in builtPages {
            try plugins.runBeforeRender(routeContext: PluginRouteContext(route: page.route))
        }
        try writer.writePages(builtPages, to: outputRoot)
        try writer.copyProjectPublicAssets(projectRoot: projectRoot, outputRoot: outputRoot)
        try writer.copyProjectStaticAssets(projectRoot: projectRoot, outputRoot: outputRoot)
        for page in builtPages {
            try plugins.runAfterRender(outputPath: writer.emittedOutputPath(forRoute: page.route, outputRoot: outputRoot, projectRoot: projectRoot))
        }
        try themes.copyThemeAssets(theme: siteConfig.theme, projectRoot: projectRoot, outputRoot: outputRoot)
        try copyPictureVariants(filenames: pictureVariantsUsed, projectRoot: projectRoot, outputRoot: outputRoot)
        try writeSEOArtifacts(
            posts: posts,
            collections: collections,
            routes: builtPages.map(\.route),
            outputRoot: outputRoot,
            siteConfig: siteConfig,
            urlBuilder: urlBuilder
        )
        try writeSearchIndex(posts: posts, outputRoot: outputRoot)

        let report = BuildReport(outputDirectory: outputRoot, routes: builtPages.map(\.route), errors: [])
        try plugins.runOnBuildComplete(report: PluginBuildReport(routes: report.routes, errors: report.errors))
        return report
    }

    public func outputDirectory(in projectRoot: URL) -> URL {
        let siteConfig = loadSiteConfig(projectRoot: projectRoot)
        return projectRoot.appendingPathComponent(siteConfig.outputDir)
    }

    private func loadSiteConfig(projectRoot: URL) -> SiteConfig {
        let path = projectRoot.appendingPathComponent("blog.config.json")
        guard
            let data = try? Data(contentsOf: path),
            let config = try? JSONDecoder().decode(SiteConfig.self, from: data)
        else {
            return SiteConfig(title: "Blog")
        }
        return config
    }

    private func loadExtraHead(projectRoot: URL, siteConfig: SiteConfig) -> String {
        guard let relative = siteConfig.head, relative.isEmpty == false else { return "" }
        let url = projectRoot.appendingPathComponent(relative)
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            FileHandle.standardError.write(Data("warning: head file not found at \(url.path)\n".utf8))
            return ""
        }
        return contents
    }

    // swiftlint:disable:next function_parameter_count
    private func writeSEOArtifacts(
        posts: [PostDocument],
        collections: [String: Collection],
        routes: [String],
        outputRoot: URL,
        siteConfig: SiteConfig,
        urlBuilder: SiteURLBuilder
    ) throws {
        try SEOArtifactsWriter(writer: writer).writeAll(
            posts: posts,
            collections: collections,
            routes: routes,
            outputRoot: outputRoot,
            siteConfig: siteConfig,
            urlBuilder: urlBuilder
        )
    }

    private func copyPictureVariants(filenames: Set<String>, projectRoot: URL, outputRoot: URL) throws {
        guard filenames.isEmpty == false else { return }
        let cacheDir = projectRoot.appendingPathComponent(".inkwell-cache/images", isDirectory: true)
        let outDir = outputRoot.appendingPathComponent("_processed", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        for filename in filenames {
            let source = cacheDir.appendingPathComponent(filename)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            let destination = outDir.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
        }
    }

    private func writeSearchIndex(posts: [PostDocument], outputRoot: URL) throws {
        let entries = posts
            .filter { $0.frontMatter.draft != true }
            .compactMap { post -> SearchIndexEntry? in
                guard let slug = post.frontMatter.slug, let title = post.frontMatter.title else { return nil }

                let summary = post.frontMatter.summary ?? ""
                let body = normalizedSearchText(post.body)
                let tags = post.frontMatter.tags ?? []
                let categories = post.frontMatter.categories ?? []

                return SearchIndexEntry(
                    title: title,
                    slug: slug,
                    summary: summary,
                    date: post.frontMatter.date ?? "",
                    tags: tags,
                    categories: categories,
                    body: String(body.prefix(1200))
                )
            }

        let payload = SearchIndexPayload(posts: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        guard let json = String(data: data, encoding: .utf8) else {
            throw BuildPipelineError.searchIndexEncodingFailed
        }
        try writer.writeFile(relativePath: "search-index.json", content: json, to: outputRoot)
    }

    private func validateTaxonomySlugUniqueness(posts: [PostDocument]) throws {
        if let collision = TaxonomySlugCollisionValidator.firstCollision(in: posts) {
            throw BuildPipelineError.taxonomySlugCollision(kind: collision.kind, slug: collision.slug, labels: collision.labels)
        }
    }

    private func normalizedSearchText(_ markdown: String) -> String {
        let noFenceMarkers = markdown.replacingOccurrences(of: "```", with: " ")
        let noInlineCode = noFenceMarkers.replacingOccurrences(of: "`", with: " ")
        let noLinks = noInlineCode.replacingOccurrences(of: "\\[(.*?)\\]\\((.*?)\\)", with: "$1", options: .regularExpression)
        let noTokens = noLinks.replacingOccurrences(of: "[#>*_~\\-]", with: " ", options: .regularExpression)
        let compactWhitespace = noTokens.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return compactWhitespace.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}

struct SiteURLBuilder {
    let baseURL: String
    private let basePath: String
    /// Language prefix for non-default languages. Empty for the default
    /// language. Always rendered as `/<lang>` (no trailing slash).
    let langPrefix: String

    init(baseURL: String, langPrefix: String = "") {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "/" {
            self.baseURL = "http://localhost"
        } else if trimmed.hasSuffix("/") {
            self.baseURL = String(trimmed.dropLast())
        } else {
            self.baseURL = trimmed
        }

        if let components = URLComponents(string: self.baseURL),
           components.path.isEmpty == false,
           components.path != "/" {
            self.basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        } else {
            self.basePath = ""
        }

        let normalized = langPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            self.langPrefix = ""
        } else if normalized.hasPrefix("/") {
            self.langPrefix = normalized
        } else {
            self.langPrefix = "/\(normalized)"
        }
    }

    func compose(route: String) -> String {
        baseURL + langPrefix + route
    }

    func link(for route: String) -> String {
        if basePath.isEmpty {
            return langPrefix + route
        }
        return basePath + langPrefix + route
    }

    /// Builds a URL for a static asset (image, video, font, JS). Asset paths
    /// are language-agnostic — they live at canonical locations served from
    /// every language URL, so they get the basePath (for sub-path deploys)
    /// but NOT the language prefix.
    func assetLink(for path: String) -> String {
        if basePath.isEmpty {
            return path
        }
        return basePath + path
    }
}

private struct SearchIndexPayload: Codable {
    let posts: [SearchIndexEntry]
}

private struct SearchIndexEntry: Codable {
    let title: String
    let slug: String
    let summary: String
    let date: String
    let tags: [String]
    let categories: [String]
    let body: String
}
