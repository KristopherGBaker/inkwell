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
        let posts = try loader.loadPosts(in: projectRoot)
        var rendered: [String: String] = [:]

        for post in posts {
            try SchemaValidator.validate(frontMatter: post.frontMatter)
            try plugins.runBeforeParse(contentPath: post.sourcePath.path)
            guard let slug = post.frontMatter.slug else { continue }
            let html = try renderer.render(post.body)
            try plugins.runAfterParse(contentDocument: PluginDocument(slug: slug, content: post.body))
            rendered[slug] = html
        }

        try validateTaxonomySlugUniqueness(posts: posts)

        let data = try dataLoader.load(in: projectRoot)

        var collections: [String: Collection] = [:]
        var collectionRendered: [String: [String: String]] = [:]
        if let configs = siteConfig.collections, configs.isEmpty == false {
            collections = try loader.loadCollections(configs, in: projectRoot)
            for (id, collection) in collections {
                var perSlug: [String: String] = [:]
                for item in collection.items {
                    perSlug[item.slug] = try renderer.render(item.body)
                }
                collectionRendered[id] = perSlug
            }
        }

        let pages = try loader.loadPages(in: projectRoot)
        var pageRendered: [String: String] = [:]
        for page in pages {
            pageRendered[page.route] = try renderer.render(page.body)
        }

        let plans = pageContextBuilder.buildPlans(
            posts: posts,
            renderedContent: rendered,
            baseURL: urlBuilder.baseURL,
            siteConfig: siteConfig,
            data: data,
            collections: collections,
            collectionRenderedContent: collectionRendered,
            pages: pages,
            pageRenderedContent: pageRendered
        )
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
        try writeSEOArtifacts(posts: posts, routes: builtPages.map(\.route), outputRoot: outputRoot, siteConfig: siteConfig, urlBuilder: urlBuilder)
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

    private func writeSEOArtifacts(posts: [PostDocument], routes: [String], outputRoot: URL, siteConfig: SiteConfig, urlBuilder: SiteURLBuilder) throws {
        let sitemapEntries = routes.map { route in
            "  <url><loc>\(xmlEscape(urlBuilder.compose(route: route)))</loc></url>"
        }.joined(separator: "\n")

        let sitemap = """
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        \(sitemapEntries)
        </urlset>
        """

        let robots = """
        User-agent: *
        Allow: /
        Sitemap: \(urlBuilder.compose(route: "/sitemap.xml"))
        """

        let feedPosts = posts
            .filter { $0.frontMatter.draft != true }
            .sorted { ($0.frontMatter.date ?? "") > ($1.frontMatter.date ?? "") }
            .prefix(20)
            .compactMap { post -> String? in
                guard let slug = post.frontMatter.slug, let title = post.frontMatter.title else { return nil }
                let link = urlBuilder.compose(route: "/posts/\(slug)/")
                let date = post.frontMatter.date ?? ""
                let summary = xmlEscape(post.frontMatter.summary ?? "")
                return """
                  <item>
                    <title>\(xmlEscape(title))</title>
                    <link>\(xmlEscape(link))</link>
                    <guid>\(xmlEscape(link))</guid>
                    <pubDate>\(xmlEscape(date))</pubDate>
                    <description>\(summary)</description>
                  </item>
                """
            }
            .joined(separator: "\n")

        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <title>\(xmlEscape(siteConfig.title))</title>
            <link>\(xmlEscape(urlBuilder.baseURL))</link>
            <description>Recent posts from \(xmlEscape(siteConfig.title))</description>
        \(feedPosts)
          </channel>
        </rss>
        """

        try writer.writeFile(relativePath: "sitemap.xml", content: sitemap, to: outputRoot)
        try writer.writeFile(relativePath: "robots.txt", content: robots, to: outputRoot)
        try writer.writeFile(relativePath: "rss.xml", content: rss, to: outputRoot)
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

    private func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

struct SiteURLBuilder {
    let baseURL: String
    private let basePath: String

    init(baseURL: String) {
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
    }

    func compose(route: String) -> String {
        baseURL + route
    }

    func link(for route: String) -> String {
        if basePath.isEmpty {
            return route
        }
        return basePath + route
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
