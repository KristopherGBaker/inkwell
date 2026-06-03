// swiftlint:disable file_length
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

// swiftlint:disable:next type_body_length
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

    public func run(in projectRoot: URL, mode: BuildMode = .build) throws -> BuildReport {
        let siteConfig = loadSiteConfig(projectRoot: projectRoot)
        let outputRoot = projectRoot.appendingPathComponent(siteConfig.outputDir)
        let urlBuilder = SiteURLBuilder(baseURL: siteConfig.baseURL)
        let pictureRewriter = PictureRewriter(projectRoot: projectRoot)
        let coverImageResolver = ResponsiveImageResolver(projectRoot: projectRoot)
        let ogCardGenerator = OGCardGenerator(projectRoot: projectRoot)
        let renderBody = makeBodyRenderer(projectRoot: projectRoot)
        var pictureVariantsUsed: Set<String> = []

        let posts = try loader.loadPosts(in: projectRoot)
        let renderedPosts = try renderPosts(posts, renderBody: renderBody, rewriter: pictureRewriter)
        pictureVariantsUsed.formUnion(renderedPosts.variants)
        try validateTaxonomySlugUniqueness(posts: posts)

        let defaultLanguage = siteConfig.i18n?.resolvedDefaultLanguage ?? "en"
        let configuredLanguages = siteConfig.i18n?.resolvedLanguages ?? [defaultLanguage]
        let dataByLang = try loadDataByLanguage(configuredLanguages, in: projectRoot)

        let renderedCollections = try renderCollections(
            siteConfig,
            defaultLanguage: defaultLanguage,
            configuredLanguages: configuredLanguages,
            in: projectRoot,
            renderBody: renderBody,
            rewriter: pictureRewriter
        )
        pictureVariantsUsed.formUnion(renderedCollections.variants)

        let pages = try loader.loadPages(
            in: projectRoot,
            defaultLanguage: defaultLanguage,
            configuredLanguages: configuredLanguages
        )
        let renderedPages = try renderPages(pages, renderBody: renderBody, rewriter: pictureRewriter)
        pictureVariantsUsed.formUnion(renderedPages.variants)

        let resolvingBuilder = PageContextBuilder(
            imageResolver: { path, alt in coverImageResolver.resolve(path: path, alt: alt)?.contextDict() },
            ogCardResolver: makeOGCardResolver(
                siteConfig: siteConfig,
                generator: ogCardGenerator,
                urlBuilder: urlBuilder
            )
        )
        let plans = resolvingBuilder.buildPlans(
            posts: posts,
            renderedContent: renderedPosts.rendered,
            baseURL: urlBuilder.baseURL,
            siteConfig: siteConfig,
            dataByLanguage: dataByLang,
            collections: renderedCollections.collections,
            collectionRenderedContent: renderedCollections.rendered,
            pages: pages,
            pageRenderedContent: renderedPages.rendered,
            mode: mode
        )
        pictureVariantsUsed.formUnion(coverImageResolver.usedVariantFilenames)

        let builtPages = try renderTemplates(plans: plans, siteConfig: siteConfig, projectRoot: projectRoot)
        return try emitArtifacts(
            builtPages: builtPages,
            posts: posts,
            collections: renderedCollections.collections,
            pictureVariants: pictureVariantsUsed,
            ogCardFilenames: ogCardGenerator.generatedFilenames,
            projectRoot: projectRoot,
            outputRoot: outputRoot,
            siteConfig: siteConfig,
            urlBuilder: urlBuilder
        )
    }

    /// Builds the markdown→HTML closure used for every content body: math
    /// extraction, cmark render, node-rendered math, then restitch.
    private func makeBodyRenderer(projectRoot: URL) -> (String) throws -> String {
        let mathEngine = MathEngine()
        let scriptsDir = projectRoot.appendingPathComponent("scripts")
        return { body in
            let extract = mathEngine.extract(markdown: body)
            let html = try self.renderer.render(extract.markdown)
            let mathHTML = mathEngine.renderViaNode(runs: extract.runs, scriptDirectory: scriptsDir)
            return mathEngine.restitch(html: html, runs: extract.runs, renderedHTML: mathHTML)
        }
    }

    private func makeOGCardResolver(
        siteConfig: SiteConfig,
        generator: OGCardGenerator,
        urlBuilder: SiteURLBuilder
    ) -> OGCardURLResolver {
        let siteAuthor = siteConfig.author?.name ?? siteConfig.title
        let siteTheme = siteConfig.theme
        return { title, subtitle, lang in
            let spec = OGCardSpec(
                title: title,
                subtitle: subtitle,
                author: siteAuthor,
                lang: lang,
                theme: siteTheme,
                accent: "#fbbf24"
            )
            guard let filename = generator.ensureCard(spec: spec) else { return nil }
            return urlBuilder.assetLink(for: "/og/\(filename)")
        }
    }

    /// Per-language data dicts. Files without a language suffix back-fill every
    /// language; suffixed files override only their own language.
    private func loadDataByLanguage(_ languages: [String], in projectRoot: URL) throws -> [String: [String: Any]] {
        var dataByLang: [String: [String: Any]] = [:]
        for lang in languages {
            dataByLang[lang] = try dataLoader.load(in: projectRoot, lang: lang)
        }
        return dataByLang
    }

    private func renderPosts(
        _ posts: [PostDocument],
        renderBody: (String) throws -> String,
        rewriter: PictureRewriter
    ) throws -> (rendered: [String: String], variants: Set<String>) {
        var rendered: [String: String] = [:]
        var variants: Set<String> = []
        for post in posts {
            try SchemaValidator.validate(frontMatter: post.frontMatter)
            try plugins.runBeforeParse(contentPath: post.sourcePath.path)
            guard let slug = post.frontMatter.slug else { continue }
            let withMath = try renderBody(post.body)
            try plugins.runAfterParse(contentDocument: PluginDocument(slug: slug, content: post.body))
            let result = rewriter.rewrite(html: withMath)
            variants.formUnion(result.usedVariantFilenames)
            rendered[slug] = result.html
        }
        return (rendered, variants)
    }

    // swiftlint:disable:next function_parameter_count
    private func renderCollections(
        _ siteConfig: SiteConfig,
        defaultLanguage: String,
        configuredLanguages: [String],
        in projectRoot: URL,
        renderBody: (String) throws -> String,
        rewriter: PictureRewriter
    ) throws -> (
        collections: [String: Collection],
        rendered: [String: [String: [String: String]]],
        variants: Set<String>
    ) {
        var variants: Set<String> = []
        var collectionRendered: [String: [String: [String: String]]] = [:]
        guard let configs = siteConfig.collections, configs.isEmpty == false else {
            return ([:], collectionRendered, variants)
        }
        let collections = try loader.loadCollections(
            configs,
            in: projectRoot,
            defaultLanguage: defaultLanguage,
            configuredLanguages: configuredLanguages
        )
        for (id, collection) in collections {
            var perLang: [String: [String: String]] = [:]
            let collectionRoute = normalizedRoute(collection.config.route)
            for item in collection.items {
                let withMath = try renderBody(item.body)
                let canonicalBase = "\(collectionRoute)\(item.slug)/"
                let withAssets = AssetURLRewriter.rewriteRelativeURLs(in: withMath, base: canonicalBase)
                let result = rewriter.rewrite(html: withAssets)
                variants.formUnion(result.usedVariantFilenames)
                perLang[item.lang, default: [:]][item.slug] = result.html
            }
            collectionRendered[id] = perLang
        }
        return (collections, collectionRendered, variants)
    }

    private func renderPages(
        _ pages: [Page],
        renderBody: (String) throws -> String,
        rewriter: PictureRewriter
    ) throws -> (rendered: [String: [String: String]], variants: Set<String>) {
        var pageRendered: [String: [String: String]] = [:]
        var variants: Set<String> = []
        for page in pages {
            let withMath = try renderBody(page.body)
            let withAssets = AssetURLRewriter.rewriteRelativeURLs(in: withMath, base: page.route)
            let result = rewriter.rewrite(html: withAssets)
            variants.formUnion(result.usedVariantFilenames)
            pageRendered[page.lang, default: [:]][page.route] = result.html
        }
        return (pageRendered, variants)
    }

    /// Normalizes a configured route to leading- and trailing-slash form.
    private func normalizedRoute(_ raw: String) -> String {
        var route = raw
        if route.hasPrefix("/") == false { route = "/" + route }
        if route.hasSuffix("/") == false { route += "/" }
        return route
    }

    /// Renders each plan's template and injects per-theme head assets.
    private func renderTemplates(plans: [PagePlan], siteConfig: SiteConfig, projectRoot: URL) throws -> [BuiltPage] {
        let templateRenderer = try TemplateRenderer(theme: siteConfig.theme, projectRoot: projectRoot)
        let extraHead = loadExtraHead(projectRoot: projectRoot, siteConfig: siteConfig)
        return try plans.map { plan in
            let html = try templateRenderer.render(template: plan.template, context: plan.context)
            let hasMath = html.contains("class=\"math math-inline\"")
                || html.contains("class=\"math math-block\"")
            let injected = themes.injectHeadAssets(
                into: html,
                baseURL: siteConfig.baseURL,
                extraHead: extraHead,
                theme: siteConfig.theme,
                hasMath: hasMath
            )
            return BuiltPage(route: plan.route, html: injected)
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func emitArtifacts(
        builtPages: [BuiltPage],
        posts: [PostDocument],
        collections: [String: Collection],
        pictureVariants: Set<String>,
        ogCardFilenames: Set<String>,
        projectRoot: URL,
        outputRoot: URL,
        siteConfig: SiteConfig,
        urlBuilder: SiteURLBuilder
    ) throws -> BuildReport {
        for page in builtPages {
            try plugins.runBeforeRender(routeContext: PluginRouteContext(route: page.route))
        }
        try writer.writePages(builtPages, to: outputRoot)
        try writer.copyProjectPublicAssets(projectRoot: projectRoot, outputRoot: outputRoot)
        try writer.copyProjectStaticAssets(projectRoot: projectRoot, outputRoot: outputRoot)
        for page in builtPages {
            try plugins.runAfterRender(
                outputPath: writer.emittedOutputPath(
                    forRoute: page.route,
                    outputRoot: outputRoot,
                    projectRoot: projectRoot
                )
            )
        }
        try themes.copyThemeAssets(theme: siteConfig.theme, projectRoot: projectRoot, outputRoot: outputRoot)
        try copyPictureVariants(filenames: pictureVariants, projectRoot: projectRoot, outputRoot: outputRoot)
        try copyOGCards(filenames: ogCardFilenames, projectRoot: projectRoot, outputRoot: outputRoot)
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

    private func copyOGCards(filenames: Set<String>, projectRoot: URL, outputRoot: URL) throws {
        guard filenames.isEmpty == false else { return }
        let cacheDir = projectRoot.appendingPathComponent(".inkwell-cache/og", isDirectory: true)
        let outDir = outputRoot.appendingPathComponent("og", isDirectory: true)
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
            throw BuildPipelineError.taxonomySlugCollision(
                kind: collision.kind,
                slug: collision.slug,
                labels: collision.labels
            )
        }
    }

    private func normalizedSearchText(_ markdown: String) -> String {
        let noFenceMarkers = markdown.replacingOccurrences(of: "```", with: " ")
        let noInlineCode = noFenceMarkers.replacingOccurrences(of: "`", with: " ")
        let noLinks = noInlineCode.replacingOccurrences(
            of: "\\[(.*?)\\]\\((.*?)\\)",
            with: "$1",
            options: .regularExpression
        )
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
