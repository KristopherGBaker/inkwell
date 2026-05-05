import Foundation

/// Renders and writes the sitemap, robots.txt, and RSS feed(s) for a build.
/// Extracted from `BuildPipeline` so the pipeline file stays focused on
/// orchestration and so feed/sitemap rendering is independently testable.
struct SEOArtifactsWriter {
    let writer: OutputWriter

    // swiftlint:disable:next function_parameter_count
    func writeAll(
        posts: [PostDocument],
        collections: [String: Collection],
        routes: [String],
        outputRoot: URL,
        siteConfig: SiteConfig,
        urlBuilder: SiteURLBuilder
    ) throws {
        let defaultLanguage = siteConfig.i18n?.resolvedDefaultLanguage ?? "en"
        let configuredLanguages = siteConfig.i18n?.resolvedLanguages ?? [defaultLanguage]
        let i18nEnabled = siteConfig.i18n != nil && configuredLanguages.count > 1

        let sitemap = renderSitemap(
            routes: routes,
            urlBuilder: urlBuilder,
            defaultLanguage: defaultLanguage,
            configuredLanguages: configuredLanguages,
            i18nEnabled: i18nEnabled
        )

        let robots = """
        User-agent: *
        Allow: /
        Sitemap: \(urlBuilder.compose(route: "/sitemap.xml"))
        """

        try writer.writeFile(relativePath: "sitemap.xml", content: sitemap, to: outputRoot)
        try writer.writeFile(relativePath: "robots.txt", content: robots, to: outputRoot)

        try writeRSSFeeds(
            posts: posts,
            collections: collections,
            outputRoot: outputRoot,
            siteConfig: siteConfig,
            defaultLanguage: defaultLanguage,
            configuredLanguages: configuredLanguages,
            i18nEnabled: i18nEnabled
        )
    }

    // MARK: - Sitemap

    func renderSitemap(
        routes: [String],
        urlBuilder: SiteURLBuilder,
        defaultLanguage: String,
        configuredLanguages: [String],
        i18nEnabled: Bool
    ) -> String {
        if i18nEnabled == false {
            let entries = routes.map { route in
                "  <url><loc>\(xmlEscape(urlBuilder.compose(route: route)))</loc></url>"
            }.joined(separator: "\n")
            return """
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
            \(entries)
            </urlset>
            """
        }

        // /<defaultLang>/... routes are meta-refresh aliases for the
        // canonical default-language URLs. Excluding them here keeps the
        // sitemap from advertising two URLs that resolve to the same content.
        let defaultLangAliasPrefix = "/\(defaultLanguage)/"
        let filteredRoutes = routes.filter { route in
            route != "/\(defaultLanguage)" && route.hasPrefix(defaultLangAliasPrefix) == false
        }

        let nonDefaultLanguages = configuredLanguages.filter { $0 != defaultLanguage }
        let groupsByCanonical = groupRoutesByCanonical(
            filteredRoutes,
            defaultLanguage: defaultLanguage,
            nonDefaultLanguages: nonDefaultLanguages
        )

        var entries: [String] = []
        for route in filteredRoutes {
            let canonical = canonicalForm(of: route, nonDefaultLanguages: nonDefaultLanguages)
            let group = groupsByCanonical[canonical] ?? [:]
            var lines: [String] = ["  <url>"]
            lines.append("    <loc>\(xmlEscape(urlBuilder.compose(route: route)))</loc>")
            for lang in configuredLanguages {
                guard let altRoute = group[lang] else { continue }
                lines.append(
                    "    <xhtml:link rel=\"alternate\" hreflang=\"\(lang)\" "
                    + "href=\"\(xmlEscape(urlBuilder.compose(route: altRoute)))\"/>"
                )
            }
            if let defaultRoute = group[defaultLanguage] {
                lines.append(
                    "    <xhtml:link rel=\"alternate\" hreflang=\"x-default\" "
                    + "href=\"\(xmlEscape(urlBuilder.compose(route: defaultRoute)))\"/>"
                )
            }
            lines.append("  </url>")
            entries.append(lines.joined(separator: "\n"))
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
        \(entries.joined(separator: "\n"))
        </urlset>
        """
    }

    private func groupRoutesByCanonical(
        _ routes: [String],
        defaultLanguage: String,
        nonDefaultLanguages: [String]
    ) -> [String: [String: String]] {
        var groups: [String: [String: String]] = [:]
        for route in routes {
            let canonical = canonicalForm(of: route, nonDefaultLanguages: nonDefaultLanguages)
            let lang = languagePrefix(of: route, nonDefaultLanguages: nonDefaultLanguages) ?? defaultLanguage
            groups[canonical, default: [:]][lang] = route
        }
        return groups
    }

    private func canonicalForm(of route: String, nonDefaultLanguages: [String]) -> String {
        for lang in nonDefaultLanguages {
            let prefix = "/\(lang)"
            if route == prefix { return "/" }
            if route.hasPrefix(prefix + "/") { return String(route.dropFirst(prefix.count)) }
        }
        return route
    }

    private func languagePrefix(of route: String, nonDefaultLanguages: [String]) -> String? {
        for lang in nonDefaultLanguages {
            let prefix = "/\(lang)"
            if route == prefix || route.hasPrefix(prefix + "/") { return lang }
        }
        return nil
    }

    // MARK: - RSS

    // swiftlint:disable:next function_parameter_count
    private func writeRSSFeeds(
        posts: [PostDocument],
        collections: [String: Collection],
        outputRoot: URL,
        siteConfig: SiteConfig,
        defaultLanguage: String,
        configuredLanguages: [String],
        i18nEnabled: Bool
    ) throws {
        // i18n + a primary blog collection: emit one feed per language.
        // Otherwise: keep the legacy posts-based feed at /rss.xml.
        if i18nEnabled, let blog = primaryBlogCollection(siteConfig: siteConfig, collections: collections) {
            for lang in configuredLanguages {
                let langPrefix = (lang == defaultLanguage) ? "" : lang
                let feedBuilder = SiteURLBuilder(baseURL: siteConfig.baseURL, langPrefix: langPrefix)
                let rss = renderRSSFromCollection(
                    blog,
                    siteConfig: siteConfig,
                    lang: lang,
                    feedBuilder: feedBuilder
                )
                let path = (lang == defaultLanguage) ? "rss.xml" : "\(lang)/rss.xml"
                try writer.writeFile(relativePath: path, content: rss, to: outputRoot)
            }
            return
        }

        let urlBuilder = SiteURLBuilder(baseURL: siteConfig.baseURL)
        let rss = renderRSSFromPosts(posts, siteConfig: siteConfig, urlBuilder: urlBuilder)
        try writer.writeFile(relativePath: "rss.xml", content: rss, to: outputRoot)
    }

    /// Picks the collection that should drive the blog RSS feed. Prefers an
    /// `id == "posts"` collection (matches the legacy `/posts/` shape and the
    /// `inkwell init` scaffold), then falls back to whichever collection was
    /// declared first in `blog.config.json`.
    func primaryBlogCollection(siteConfig: SiteConfig, collections: [String: Collection]) -> Collection? {
        guard let configs = siteConfig.collections, configs.isEmpty == false else { return nil }
        if let postsCollection = collections["posts"] {
            return postsCollection
        }
        guard let firstID = configs.first?.id else { return nil }
        return collections[firstID]
    }

    func renderRSSFromCollection(
        _ collection: Collection,
        siteConfig: SiteConfig,
        lang: String,
        feedBuilder: SiteURLBuilder
    ) -> String {
        let route: String = {
            var raw = collection.config.route
            if raw.hasPrefix("/") == false { raw = "/" + raw }
            if raw.hasSuffix("/") == false { raw += "/" }
            return raw
        }()

        let items = collection.items
            .filter { $0.lang == lang && $0.draft != true }
            .sorted { ($0.date ?? "") > ($1.date ?? "") }
            .prefix(20)
            .map { item -> String in
                let link = feedBuilder.compose(route: "\(route)\(item.slug)/")
                let date = item.date ?? ""
                let summary = xmlEscape(item.summary ?? "")
                return """
                  <item>
                    <title>\(xmlEscape(item.title))</title>
                    <link>\(xmlEscape(link))</link>
                    <guid>\(xmlEscape(link))</guid>
                    <pubDate>\(xmlEscape(date))</pubDate>
                    <description>\(summary)</description>
                  </item>
                """
            }
            .joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <title>\(xmlEscape(siteConfig.title))</title>
            <link>\(xmlEscape(feedBuilder.compose(route: "/")))</link>
            <description>Recent entries from \(xmlEscape(siteConfig.title))</description>
            <language>\(xmlEscape(lang))</language>
        \(items)
          </channel>
        </rss>
        """
    }

    func renderRSSFromPosts(
        _ posts: [PostDocument],
        siteConfig: SiteConfig,
        urlBuilder: SiteURLBuilder
    ) -> String {
        let items = posts
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

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <title>\(xmlEscape(siteConfig.title))</title>
            <link>\(xmlEscape(urlBuilder.baseURL))</link>
            <description>Recent posts from \(xmlEscape(siteConfig.title))</description>
        \(items)
          </channel>
        </rss>
        """
    }
}

/// XML-escapes the five characters that need escaping in attribute and text
/// content. Public-internal so other build artifacts (e.g. search index XML
/// shapes, future feed formats) can reuse the same escaping rules.
func xmlEscape(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}
