import Foundation

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
        if let feeds = siteConfig.feeds, feeds.resolvedCollectionIDs.isEmpty == false {
            try writeConfiguredFeeds(
                feeds: feeds,
                collections: collections,
                collectionRenderedContent: collectionRenderedContent,
                outputRoot: outputRoot,
                siteConfig: siteConfig,
                defaultLanguage: defaultLanguage,
                configuredLanguages: configuredLanguages,
                i18nEnabled: i18nEnabled
            )
            return
        }

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

    /// Path prefix (no leading slash, trailing slash) used for a collection's
    /// feed files, e.g. `/posts` → `"posts/"`, `/` → `""`.
    private func feedPathPrefix(forRoute raw: String) -> String {
        var route = normalizedFeedRoute(raw)
        if route.hasPrefix("/") { route.removeFirst() }
        return route
    }

    /// Short label for a per-collection feed channel title, derived from the
    /// collection's headline or its capitalized id.
    private func collectionLabel(_ collection: Collection) -> String? {
        if let headline = collection.config.headline, headline.isEmpty == false { return headline }
        let id = collection.config.id
        guard let first = id.first else { return nil }
        return first.uppercased() + id.dropFirst()
    }

    // Emits per-collection feeds for each configured id plus, when enabled, a
    // combined feed at the site root. One set per language under i18n.
    // swiftlint:disable:next function_parameter_count
    private func writeConfiguredFeeds(
        feeds: FeedConfig,
        collections: [String: Collection],
        collectionRenderedContent: [String: [String: [String: String]]],
        outputRoot: URL,
        siteConfig: SiteConfig,
        defaultLanguage: String,
        configuredLanguages: [String],
        i18nEnabled: Bool
    ) throws {
        let languages = i18nEnabled ? configuredLanguages : [defaultLanguage]
        for lang in languages {
            let isDefault = (lang == defaultLanguage)
            let langSeg: String? = isDefault ? nil : lang
            let feedBuilder = SiteURLBuilder(baseURL: siteConfig.baseURL, langPrefix: isDefault ? "" : lang)

            var combined: [FeedItem] = []
            for id in feeds.resolvedCollectionIDs {
                guard let collection = collections[id] else { continue }
                let rendered = collectionRenderedContent[id]?[lang] ?? [:]
                let items = collectionFeedItems(
                    collection: collection,
                    collections: collections,
                    lang: lang,
                    rendered: rendered,
                    feedBuilder: feedBuilder
                )
                combined.append(contentsOf: items)

                let pathPrefix = feedPathPrefix(forRoute: collection.config.route)
                let channel = makeChannel(
                    siteConfig: siteConfig,
                    lang: lang,
                    emitLanguage: i18nEnabled,
                    feedBuilder: feedBuilder,
                    items: Array(items.prefix(feeds.resolvedLimit)),
                    pathPrefix: pathPrefix,
                    label: collectionLabel(collection)
                )
                try writeChannel(channel, langSegment: langSeg, pathPrefix: pathPrefix, to: outputRoot)
            }

            if feeds.emitsCombined {
                let merged = combined
                    .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
                    .prefix(feeds.resolvedLimit)
                let channel = makeChannel(
                    siteConfig: siteConfig,
                    lang: lang,
                    emitLanguage: i18nEnabled,
                    feedBuilder: feedBuilder,
                    items: Array(merged)
                )
                try writeChannel(channel, langSegment: langSeg, to: outputRoot)
            }
        }
    }

    /// Builds sorted (newest-first), uncapped feed items for a collection.
    /// Handles child collections by linking items under their parent
    /// (`<parentRoute>/<parentSlug>/<slug>/`) and resolves each item's date
    /// with a `year` fallback for collections that date by year (e.g. work).
    private func collectionFeedItems(
        collection: Collection,
        collections: [String: Collection],
        lang: String,
        rendered: [String: String],
        feedBuilder: SiteURLBuilder
    ) -> [FeedItem] {
        collection.items
            .filter { $0.lang == lang && $0.draft != true }
            .map { item -> FeedItem in
                let link = feedItemLink(
                    collection: collection,
                    item: item,
                    collections: collections,
                    feedBuilder: feedBuilder
                )
                let content = rendered[item.slug].map { absolutizeFeedURLs(in: $0, baseURL: feedBuilder.baseURL) }
                return FeedItem(
                    title: item.title,
                    link: link,
                    date: feedItemDate(item),
                    summary: item.summary ?? "",
                    contentHTML: content,
                    categories: item.tags ?? []
                )
            }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    /// Composes a feed item's absolute link. Child-collection items route under
    /// their parent item; everything else under its own collection route.
    private func feedItemLink(
        collection: Collection,
        item: CollectionItem,
        collections: [String: Collection],
        feedBuilder: SiteURLBuilder
    ) -> String {
        if collection.config.isChild,
           let parentId = collection.config.parent,
           let parentRoute = collections[parentId].map({ normalizedFeedRoute($0.config.route) }),
           let parentSlug = item.frontMatter[collection.config.resolvedParentField] as? String {
            return feedBuilder.compose(route: "\(parentRoute)\(parentSlug)/\(item.slug)/")
        }
        return feedBuilder.compose(route: "\(normalizedFeedRoute(collection.config.route))\(item.slug)/")
    }

    /// Resolves a feed item's publish date: the `date` field if present, else
    /// January 1 of the item's `year` front-matter (Int or String), else nil.
    private func feedItemDate(_ item: CollectionItem) -> Date? {
        if let parsed = FeedDate.parse(item.date) { return parsed }
        let yearValue = item.frontMatter["year"]
        let year: Int?
        if let intYear = yearValue as? Int {
            year = intYear
        } else if let stringYear = yearValue as? String {
            year = Int(stringYear)
        } else {
            year = nil
        }
        guard let year else { return nil }
        return FeedDate.parse("\(year)-01-01T00:00:00Z")
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
        items: [FeedItem],
        pathPrefix: String = "",
        label: String? = nil
    ) -> FeedChannel {
        let overlay = siteConfig.translations?[lang]
        let overlayTitle = overlay?.title.flatMap { $0.isEmpty ? nil : $0 }
        let siteTitle = overlayTitle ?? siteConfig.title
        let title = label.map { "\(siteTitle) · \($0)" } ?? siteTitle
        let description = overlay?.description ?? siteConfig.description ?? "Recent entries from \(siteTitle)"
        let updated = items.compactMap { $0.date }.max()
        return FeedChannel(
            title: title,
            homeLink: feedBuilder.compose(route: "/"),
            summary: description,
            language: emitLanguage ? lang : nil,
            authorName: siteConfig.author?.name,
            authorEmail: siteConfig.author?.email,
            selfRSSURL: feedBuilder.compose(route: "/\(pathPrefix)rss.xml"),
            selfAtomURL: feedBuilder.compose(route: "/\(pathPrefix)atom.xml"),
            selfJSONURL: feedBuilder.compose(route: "/\(pathPrefix)feed.json"),
            updated: updated,
            items: items
        )
    }

    private func writeChannel(
        _ channel: FeedChannel,
        langSegment: String?,
        pathPrefix: String = "",
        to outputRoot: URL
    ) throws {
        let langPrefix = langSegment.map { "\($0)/" } ?? ""
        let prefix = "\(langPrefix)\(pathPrefix)"
        try writer.writeFile(relativePath: "\(prefix)rss.xml", content: renderRSS(channel), to: outputRoot)
        try writer.writeFile(relativePath: "\(prefix)atom.xml", content: renderAtom(channel), to: outputRoot)
        try writer.writeFile(relativePath: "\(prefix)feed.json", content: renderJSONFeed(channel), to: outputRoot)
    }
}
