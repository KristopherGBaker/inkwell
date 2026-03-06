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

public struct BuildPipeline {
    private let loader: ContentLoader
    private let renderer: MarkdownRenderer
    private let routeBuilder: RouteBuilder
    private let writer: OutputWriter
    private let plugins: PluginManager
    private let themes: ThemeManager

    public init(
        loader: ContentLoader = ContentLoader(),
        renderer: MarkdownRenderer = MarkdownRenderer(),
        routeBuilder: RouteBuilder = RouteBuilder(),
        writer: OutputWriter = OutputWriter(),
        plugins: PluginManager = PluginManager(),
        themes: ThemeManager = ThemeManager()
    ) {
        self.loader = loader
        self.renderer = renderer
        self.routeBuilder = routeBuilder
        self.writer = writer
        self.plugins = plugins
        self.themes = themes
    }

    public func run(in projectRoot: URL) throws -> BuildReport {
        let outputRoot = projectRoot.appendingPathComponent("docs")
        let siteConfig = loadSiteConfig(projectRoot: projectRoot)
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

        var pages = routeBuilder.buildPages(posts: posts, renderedContent: rendered)
        pages = pages.map { BuiltPage(route: $0.route, html: themes.injectHeadAssets(into: $0.html)) }

        for page in pages {
            try plugins.runBeforeRender(routeContext: PluginRouteContext(route: page.route))
        }
        try writer.writePages(pages, to: outputRoot)
        for page in pages {
            let route = page.route == "/" ? "index.html" : page.route + "index.html"
            try plugins.runAfterRender(outputPath: route)
        }
        try themes.copyDefaultAssets(projectRoot: projectRoot, outputRoot: outputRoot)
        try writeSEOArtifacts(posts: posts, routes: pages.map(\.route), outputRoot: outputRoot, siteConfig: siteConfig)
        try writeSearchIndex(posts: posts, outputRoot: outputRoot)

        let report = BuildReport(outputDirectory: outputRoot, routes: pages.map(\.route), errors: [])
        try plugins.runOnBuildComplete(report: PluginBuildReport(routes: report.routes, errors: report.errors))
        return report
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

    private func writeSEOArtifacts(posts: [PostDocument], routes: [String], outputRoot: URL, siteConfig: SiteConfig) throws {
        let baseURL = normalizedBaseURL(siteConfig.baseURL)
        let sitemapEntries = routes.map { route in
            "  <url><loc>\(xmlEscape(composeURL(baseURL: baseURL, route: route)))</loc></url>"
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
        Sitemap: \(composeURL(baseURL: baseURL, route: "/sitemap.xml"))
        """

        let feedPosts = posts
            .filter { $0.frontMatter.draft != true }
            .sorted { ($0.frontMatter.date ?? "") > ($1.frontMatter.date ?? "") }
            .prefix(20)
            .compactMap { post -> String? in
                guard let slug = post.frontMatter.slug, let title = post.frontMatter.title else { return nil }
                let link = composeURL(baseURL: baseURL, route: "/posts/\(slug)/")
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
            <link>\(xmlEscape(baseURL))</link>
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
            throw NSError(domain: "BuildPipeline", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode search index"])
        }
        try writer.writeFile(relativePath: "search-index.json", content: json, to: outputRoot)
    }

    private func normalizedSearchText(_ markdown: String) -> String {
        let noFenceMarkers = markdown.replacingOccurrences(of: "```", with: " ")
        let noInlineCode = noFenceMarkers.replacingOccurrences(of: "`", with: " ")
        let noLinks = noInlineCode.replacingOccurrences(of: "\\[(.*?)\\]\\((.*?)\\)", with: "$1", options: .regularExpression)
        let noTokens = noLinks.replacingOccurrences(of: "[#>*_~\\-]", with: " ", options: .regularExpression)
        let compactWhitespace = noTokens.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return compactWhitespace.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedBaseURL(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "/" {
            return "http://localhost"
        }
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    private func composeURL(baseURL: String, route: String) -> String {
        let normalizedRoute = route == "/" ? "/" : route
        return baseURL + normalizedRoute
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
