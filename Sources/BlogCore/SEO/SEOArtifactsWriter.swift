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
        postRenderedContent: [String: String],
        collectionRenderedContent: [String: [String: [String: String]]],
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

        try writeFeeds(
            posts: posts,
            collections: collections,
            postRenderedContent: postRenderedContent,
            collectionRenderedContent: collectionRenderedContent,
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
}

// MARK: - Feeds

extension SEOArtifactsWriter {
    // Emits RSS 2.0, Atom 1.0, and JSON Feed for the blog. With i18n + a
    // primary blog collection, one set per language (`/rss.xml`, `/atom.xml`,
    // `/feed.json` and `/<lang>/...`). Otherwise a single monolingual set,
    // sourced from the blog collection when present, else legacy posts.
    // swiftlint:disable:next function_parameter_count
    func writeFeeds(
        posts: [PostDocument],
        collections: [String: Collection],
        postRenderedContent: [String: String],
        collectionRenderedContent: [String: [String: [String: String]]],
        outputRoot: URL,
        siteConfig: SiteConfig,
        defaultLanguage: String,
        configuredLanguages: [String],
        i18nEnabled: Bool
    ) throws {
        if let blog = primaryBlogCollection(siteConfig: siteConfig, collections: collections) {
            let blogID = blog.config.id
            let route = normalizedFeedRoute(blog.config.route)
            let languages = i18nEnabled ? configuredLanguages : [defaultLanguage]
            for lang in languages {
                let isDefault = (lang == defaultLanguage)
                let feedBuilder = SiteURLBuilder(baseURL: siteConfig.baseURL, langPrefix: isDefault ? "" : lang)
                let renderedForLang = collectionRenderedContent[blogID]?[lang] ?? [:]
                let items = feedItems(
                    from: blog,
                    lang: lang,
                    route: route,
                    rendered: renderedForLang,
                    feedBuilder: feedBuilder
                )
                let channel = makeChannel(
                    siteConfig: siteConfig,
                    lang: lang,
                    emitLanguage: i18nEnabled,
                    feedBuilder: feedBuilder,
                    items: items
                )
                try writeChannel(channel, langSegment: isDefault ? nil : lang, to: outputRoot)
            }
            return
        }

        // No collections configured: legacy posts-based feed at the root.
        let feedBuilder = SiteURLBuilder(baseURL: siteConfig.baseURL)
        let items = legacyPostFeedItems(posts, rendered: postRenderedContent, feedBuilder: feedBuilder)
        let channel = makeChannel(
            siteConfig: siteConfig,
            lang: defaultLanguage,
            emitLanguage: false,
            feedBuilder: feedBuilder,
            items: items
        )
        try writeChannel(channel, langSegment: nil, to: outputRoot)
    }

    /// Picks the collection that should drive the blog feeds. Prefers an
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

    private func normalizedFeedRoute(_ raw: String) -> String {
        var route = raw
        if route.hasPrefix("/") == false { route = "/" + route }
        if route.hasSuffix("/") == false { route += "/" }
        return route
    }

    private func feedItems(
        from collection: Collection,
        lang: String,
        route: String,
        rendered: [String: String],
        feedBuilder: SiteURLBuilder
    ) -> [FeedItem] {
        collection.items
            .filter { $0.lang == lang && $0.draft != true }
            .sorted { ($0.date ?? "") > ($1.date ?? "") }
            .prefix(20)
            .map { item in
                let link = feedBuilder.compose(route: "\(route)\(item.slug)/")
                let content = rendered[item.slug].map { absolutizeFeedURLs(in: $0, baseURL: feedBuilder.baseURL) }
                return FeedItem(
                    title: item.title,
                    link: link,
                    date: FeedDate.parse(item.date),
                    summary: item.summary ?? "",
                    contentHTML: content,
                    categories: item.tags ?? []
                )
            }
    }

    private func legacyPostFeedItems(
        _ posts: [PostDocument],
        rendered: [String: String],
        feedBuilder: SiteURLBuilder
    ) -> [FeedItem] {
        posts
            .filter { $0.frontMatter.draft != true }
            .sorted { ($0.frontMatter.date ?? "") > ($1.frontMatter.date ?? "") }
            .prefix(20)
            .compactMap { post -> FeedItem? in
                guard let slug = post.frontMatter.slug, let title = post.frontMatter.title else { return nil }
                let link = feedBuilder.compose(route: "/posts/\(slug)/")
                let content = rendered[slug].map { absolutizeFeedURLs(in: $0, baseURL: feedBuilder.baseURL) }
                return FeedItem(
                    title: title,
                    link: link,
                    date: FeedDate.parse(post.frontMatter.date),
                    summary: post.frontMatter.summary ?? "",
                    contentHTML: content,
                    categories: post.frontMatter.tags ?? []
                )
            }
    }

    /// Resolves channel-level metadata, honoring a per-language translation
    /// overlay so localized feeds get localized title/description.
    private func makeChannel(
        siteConfig: SiteConfig,
        lang: String,
        emitLanguage: Bool,
        feedBuilder: SiteURLBuilder,
        items: [FeedItem]
    ) -> FeedChannel {
        let overlay = siteConfig.translations?[lang]
        let overlayTitle = overlay?.title.flatMap { $0.isEmpty ? nil : $0 }
        let title = overlayTitle ?? siteConfig.title
        let description = overlay?.description ?? siteConfig.description ?? "Recent entries from \(title)"
        let updated = items.compactMap { $0.date }.max()
        return FeedChannel(
            title: title,
            homeLink: feedBuilder.compose(route: "/"),
            summary: description,
            language: emitLanguage ? lang : nil,
            authorName: siteConfig.author?.name,
            authorEmail: siteConfig.author?.email,
            selfRSSURL: feedBuilder.compose(route: "/rss.xml"),
            selfAtomURL: feedBuilder.compose(route: "/atom.xml"),
            selfJSONURL: feedBuilder.compose(route: "/feed.json"),
            updated: updated,
            items: items
        )
    }

    private func writeChannel(_ channel: FeedChannel, langSegment: String?, to outputRoot: URL) throws {
        let prefix = langSegment.map { "\($0)/" } ?? ""
        try writer.writeFile(relativePath: "\(prefix)rss.xml", content: renderRSS(channel), to: outputRoot)
        try writer.writeFile(relativePath: "\(prefix)atom.xml", content: renderAtom(channel), to: outputRoot)
        try writer.writeFile(relativePath: "\(prefix)feed.json", content: renderJSONFeed(channel), to: outputRoot)
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
