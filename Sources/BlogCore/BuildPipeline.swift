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

        let report = BuildReport(outputDirectory: outputRoot, routes: pages.map(\.route), errors: [])
        try plugins.runOnBuildComplete(report: PluginBuildReport(routes: report.routes, errors: report.errors))
        return report
    }
}
