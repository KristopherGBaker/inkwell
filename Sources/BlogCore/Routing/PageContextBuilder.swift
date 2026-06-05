// swiftlint:disable file_length
import Foundation

public struct BuiltPage: Equatable {
    public let route: String
    public let html: String

    public init(route: String, html: String) {
        self.route = route
        self.html = html
    }
}

/// A render plan: which template should produce the page at `route`,
/// and what context to feed into it. Decoupled from the renderer so
/// templates can be exchanged without touching routing logic.
public struct PagePlan {
    public let route: String
    public let template: String
    public let context: [String: Any]

    public init(route: String, template: String, context: [String: Any]) {
        self.route = route
        self.template = template
        self.context = context
    }
}

private struct RenderablePost {
    let slug: String
    let title: String
    let summary: String
    let date: String
    let tags: [String]
    let categories: [String]
    let canonicalURL: String?
    let coverImage: String?
    let ogImage: String?
    let tocOptIn: Bool?
}

/// A child collection resolved against its parent for a single language: the
/// child items grouped under each parent slug (newest first), the parent's
/// display titles, and a global recency stream. Built once per language by
/// `resolveChildCollections` and consumed by parent timelines, nested update
/// pages, and the home "what I'm building" section.
private struct ResolvedChildCollection {
    let childConfig: CollectionConfig
    let parentConfig: CollectionConfig
    /// parent slug → parent item title
    let parentTitles: [String: String]
    /// parent slug → child items, sorted by date descending (newest first)
    let itemsByParentSlug: [String: [CollectionItem]]
    /// child items whose `parentField` matched no parent item
    let orphans: [CollectionItem]
    /// every non-orphan child item, newest first
    let recentItems: [CollectionItem]
}

// swiftlint:disable:next type_body_length
public struct PageContextBuilder {
    private let postsPerPage = 6
    private let imageResolver: FrontMatterImageResolver?
    private let ogCardResolver: OGCardURLResolver?

    public init(
        imageResolver: FrontMatterImageResolver? = nil,
        ogCardResolver: OGCardURLResolver? = nil
    ) {
        self.imageResolver = imageResolver
        self.ogCardResolver = ogCardResolver
    }

    public func buildPlans(
        posts: [PostDocument],
        renderedContent: [String: String],
        baseURL: String = "/",
        siteConfig: SiteConfig = SiteConfig(title: "Field Notes"),
        dataByLanguage: [String: [String: Any]] = [:],
        collections: [String: Collection] = [:],
        collectionRenderedContent: [String: [String: [String: String]]] = [:],
        pages: [Page] = [],
        pageRenderedContent: [String: [String: String]] = [:],
        mode: BuildMode = .build
    ) -> [PagePlan] {
        let defaultLang = siteConfig.i18n?.resolvedDefaultLanguage ?? "en"
        let configuredLangs = siteConfig.i18n?.resolvedLanguages ?? [defaultLang]

        var plans: [PagePlan] = []
        for lang in configuredLangs {
            // Merge rendered content: prefer the current lang's render, fall
            // back to the default language's render for items only available
            // in default language.
            let mergedCollectionRenders: [String: [String: String]] = collectionRenderedContent.mapValues { perLang in
                var merged = perLang[defaultLang] ?? [:]
                for (slug, html) in perLang[lang] ?? [:] {
                    merged[slug] = html
                }
                return merged
            }
            var mergedPageRenders = pageRenderedContent[defaultLang] ?? [:]
            for (route, html) in pageRenderedContent[lang] ?? [:] {
                mergedPageRenders[route] = html
            }

            let perLang = buildPlansForLanguage(
                lang: lang,
                defaultLanguage: defaultLang,
                allLanguages: configuredLangs,
                posts: posts,
                renderedContent: renderedContent,
                baseURL: baseURL,
                siteConfig: siteConfig,
                data: dataByLanguage[lang] ?? [:],
                collections: collections,
                collectionRenderedContent: mergedCollectionRenders,
                pages: pages,
                pageRenderedContent: mergedPageRenders,
                mode: mode
            )
            plans.append(contentsOf: perLang)
        }

        // Emit /<defaultLang>/... alias redirects so URLs are consistent
        // whether or not callers include the explicit lang prefix.
        if siteConfig.i18n != nil, configuredLangs.count > 1 {
            let urlBuilder = SiteURLBuilder(baseURL: baseURL)
            let defaultLangPrefix = "/\(defaultLang)"
            for plan in plans
            where plan.route.hasPrefix("/")
                && plan.route.hasPrefix(defaultLangPrefix + "/") == false {
                // Skip plans that already belong to a non-default language.
                let isOtherLangPlan = configuredLangs
                    .filter { $0 != defaultLang }
                    .contains { plan.route.hasPrefix("/\($0)/") || plan.route == "/\($0)/" }
                if isOtherLangPlan { continue }

                let aliasRoute = defaultLangPrefix + plan.route
                let canonicalURL = urlBuilder.compose(route: plan.route)
                plans.append(makeRedirectPlan(route: aliasRoute, canonicalURL: canonicalURL))
            }
        }

        return plans
    }

    /// Builds a plan for an HTML page that immediately redirects to `canonicalURL`
    /// via meta-refresh + JS, with a `<link rel="canonical">` so search engines
    /// don't index the alias.
    func makeRedirectPlan(route: String, canonicalURL: String) -> PagePlan {
        let context: [String: Any] = [
            "canonicalURL": canonicalURL,
            "site": [String: Any](),
            "page": [
                "type": "redirect",
                "title": "Redirecting…",
                "canonicalURL": canonicalURL
            ]
        ]
        return PagePlan(route: route, template: "layouts/redirect", context: context)
    }

    // swiftlint:disable:next function_parameter_count
    private func buildPlansForLanguage(
        lang: String,
        defaultLanguage: String,
        allLanguages: [String],
        posts: [PostDocument],
        renderedContent: [String: String],
        baseURL: String,
        siteConfig: SiteConfig,
        data: [String: Any],
        collections: [String: Collection],
        collectionRenderedContent: [String: [String: String]],
        pages: [Page],
        pageRenderedContent: [String: String],
        mode: BuildMode
    ) -> [PagePlan] {
        let langPrefix = (lang == defaultLanguage) ? "" : lang
        let urlBuilder = SiteURLBuilder(baseURL: baseURL, langPrefix: langPrefix)
        let overlay = siteConfig.translations?[lang]

        let normalizedSiteTitle = resolvedSiteTitle(siteConfig: siteConfig, overlay: overlay)
        let siteDescription = overlay?.description ?? siteConfig.description ?? normalizedSiteTitle
        let siteTagline = overlay?.tagline ?? siteConfig.tagline ?? siteDescription

        let siteContext = buildSiteContext(
            lang: lang,
            defaultLanguage: defaultLanguage,
            allLanguages: allLanguages,
            siteConfig: siteConfig,
            overlay: overlay,
            urlBuilder: urlBuilder,
            mode: mode,
            title: normalizedSiteTitle,
            description: siteDescription,
            tagline: siteTagline
        )

        if let configs = siteConfig.collections, configs.isEmpty == false {
            return collectionModePlans(
                configs: configs,
                collections: collections,
                collectionRenderedContent: collectionRenderedContent,
                pages: pages,
                pageRenderedContent: pageRenderedContent,
                home: siteConfig.home,
                overlay: overlay,
                data: data,
                siteContext: siteContext,
                urlBuilder: urlBuilder,
                lang: lang,
                defaultLanguage: defaultLanguage,
                allLanguages: allLanguages,
                baseURL: baseURL
            )
        }

        // Legacy posts path runs only for the default language; non-default
        // languages without collections produce no plans.
        guard lang == defaultLanguage else { return [] }

        return legacyPostsPlans(
            posts: posts,
            renderedContent: renderedContent,
            pages: pages,
            pageRenderedContent: pageRenderedContent,
            home: siteConfig.home,
            collections: collections,
            data: data,
            siteContext: siteContext,
            siteTitle: normalizedSiteTitle,
            siteDescription: siteDescription,
            urlBuilder: urlBuilder,
            lang: lang
        )
    }

    /// Resolves the display site title, honoring a per-language overlay and
    /// falling back to "Field Notes" when the configured title is blank.
    private func resolvedSiteTitle(siteConfig: SiteConfig, overlay: TranslationOverlay?) -> String {
        if let title = overlay?.title, title.isEmpty == false { return title }
        let trimmed = siteConfig.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Field Notes" : siteConfig.title
    }

    // Assembles the shared `site` context dict passed into every template for
    // a given language, including optional brand/analytics/author/nav keys.
    // swiftlint:disable:next function_parameter_count
    private func buildSiteContext(
        lang: String,
        defaultLanguage: String,
        allLanguages: [String],
        siteConfig: SiteConfig,
        overlay: TranslationOverlay?,
        urlBuilder: SiteURLBuilder,
        mode: BuildMode,
        title: String,
        description: String,
        tagline: String
    ) -> [String: Any] {
        var siteContext: [String: Any] = [
            "title": escapeHTML(title),
            "description": escapeHTML(description),
            "tagline": escapeHTML(tagline),
            "searchEnabled": siteConfig.searchEnabled ?? true,
            "baseURL": siteConfig.baseURL,
            "lang": lang,
            "languages": allLanguages,
            "defaultLanguage": defaultLanguage,
            "brandInitial": brandInitial(for: siteConfig),
            "copyrightLine": copyrightLine(for: siteConfig),
            "heroHeadline": heroHeadline(for: siteConfig, overlay: overlay),
            "footerCta": footerCtaContext(for: siteConfig, overlay: overlay),
            "themeCopy": themeCopyContext(for: siteConfig, overlay: overlay),
            "feeds": [
                "rss": urlBuilder.link(for: "/rss.xml"),
                "atom": urlBuilder.link(for: "/atom.xml"),
                "json": urlBuilder.link(for: "/feed.json")
            ]
        ]
        if let brandSubtitle = overlay?.author?.tagline ?? siteConfig.author?.tagline {
            siteContext["brandSubtitle"] = escapeHTML(brandSubtitle)
        }
        if let analytics = analyticsContext(for: siteConfig, mode: mode) {
            siteContext["analytics"] = analytics
        }
        if let icon = siteConfig.brandIcon {
            // URLs are written verbatim into a CSS `url("...")` expression by
            // the bundled base.html, so don't HTML-escape them — the value
            // would then be CSS-illegal (e.g. `&quot;`).
            var iconCtx: [String: String] = ["light": icon.light]
            if let dark = icon.dark { iconCtx["dark"] = dark }
            siteContext["brandIcon"] = iconCtx
        }
        if let author = siteConfig.author {
            siteContext["author"] = authorContext(author, overlay: overlay?.author, urlBuilder: urlBuilder)
        }
        if let nav = overlay?.nav ?? siteConfig.nav, nav.isEmpty == false {
            siteContext["nav"] = nav.map { item -> [String: String] in
                ["label": escapeHTML(item.label), "route": urlBuilder.link(for: item.route)]
            }
        }
        return siteContext
    }

    // Builds plans for the explicit-collections content model: one set of
    // plans per configured collection, plus standalone pages and the home page.
    // swiftlint:disable:next function_parameter_count
    private func collectionModePlans(
        configs: [CollectionConfig],
        collections: [String: Collection],
        collectionRenderedContent: [String: [String: String]],
        pages: [Page],
        pageRenderedContent: [String: String],
        home: HomeConfig?,
        overlay: TranslationOverlay?,
        data: [String: Any],
        siteContext: [String: Any],
        urlBuilder: SiteURLBuilder,
        lang: String,
        defaultLanguage: String,
        allLanguages: [String],
        baseURL: String
    ) -> [PagePlan] {
        var plans: [PagePlan] = []
        let resolvedChildren = resolveChildCollections(
            configs: configs,
            collections: collections,
            lang: lang,
            defaultLanguage: defaultLanguage
        )
        for config in configs {
            guard let collection = collections[config.id] else { continue }
            let resolvedConfig = applyOverlay(to: config, overlay: overlay)
            let resolvedItems = bestFitItems(collection.items, lang: lang, defaultLanguage: defaultLanguage)
            let langCollection = Collection(config: resolvedConfig, items: resolvedItems)
            // Child collections route their items under the parent instead of
            // generating their own list/taxonomy pages.
            if resolvedConfig.isChild {
                if let resolvedChild = resolvedChildren.byChildId[config.id] {
                    plans.append(contentsOf: makeChildCollectionPlans(
                        resolvedChild,
                        rendered: collectionRenderedContent[config.id] ?? [:],
                        site: siteContext,
                        urlBuilder: urlBuilder,
                        lang: lang,
                        defaultLanguage: defaultLanguage,
                        baseURL: baseURL
                    ))
                }
                continue
            }
            // When this collection is a parent, precompute the per-project
            // update timeline so list cards and detail pages can render it.
            let timeline = resolvedChildren.byParentId[config.id]
                .map { buildParentTimeline($0, urlBuilder: urlBuilder) }
            plans.append(contentsOf: makeCollectionPlans(
                collection: langCollection,
                rendered: collectionRenderedContent[config.id] ?? [:],
                updatesBySlug: timeline,
                site: siteContext,
                urlBuilder: urlBuilder,
                lang: lang,
                defaultLanguage: defaultLanguage,
                allLanguages: allLanguages,
                baseURL: baseURL
            ))
        }
        for page in bestFitPages(pages, lang: lang, defaultLanguage: defaultLanguage) {
            plans.append(makeStandalonePagePlan(
                page: page,
                rendered: pageRenderedContent[page.route] ?? "",
                site: siteContext,
                urlBuilder: urlBuilder,
                lang: lang,
                defaultLanguage: defaultLanguage,
                baseURL: baseURL
            ))
        }
        if let home {
            let homeRoute = (lang == defaultLanguage) ? "/" : "/\(lang)/"
            plans = plans.filter { $0.route != homeRoute }
            plans.append(makeHomePlan(
                home: applyOverlay(to: home, overlay: overlay),
                site: siteContext,
                collections: collections,
                childCollections: resolvedChildren.byChildId,
                urlBuilder: urlBuilder,
                lang: lang,
                defaultLanguage: defaultLanguage,
                allLanguages: allLanguages,
                baseURL: baseURL
            ))
        }
        return injectingData(plans, data: data)
    }

    // Builds plans for the legacy blog content model (no `collections` in
    // config): paginated landing, archive, per-post, taxonomy, pages, home.
    // swiftlint:disable:next function_parameter_count
    private func legacyPostsPlans(
        posts: [PostDocument],
        renderedContent: [String: String],
        pages: [Page],
        pageRenderedContent: [String: String],
        home: HomeConfig?,
        collections: [String: Collection],
        data: [String: Any],
        siteContext: [String: Any],
        siteTitle: String,
        siteDescription: String,
        urlBuilder: SiteURLBuilder,
        lang: String
    ) -> [PagePlan] {
        let mapped = posts.compactMap(mapPost).sorted { $0.date > $1.date }
        var plans = landingPlans(
            mapped: mapped,
            site: siteContext,
            siteTitle: siteTitle,
            siteDescription: siteDescription,
            urlBuilder: urlBuilder
        )
        plans.append(makeArchivePlan(posts: mapped, site: siteContext, urlBuilder: urlBuilder))
        for post in mapped {
            plans.append(makePostPlan(
                post: post,
                content: renderedContent[post.slug] ?? "",
                site: siteContext,
                urlBuilder: urlBuilder,
                lang: lang
            ))
        }
        plans.append(contentsOf: makeTaxonomyPlans(
            kind: "tags",
            posts: mapped,
            site: siteContext,
            urlBuilder: urlBuilder,
            extractor: { $0.tags }
        ))
        plans.append(contentsOf: makeTaxonomyPlans(
            kind: "categories",
            posts: mapped,
            site: siteContext,
            urlBuilder: urlBuilder,
            extractor: { $0.categories }
        ))
        for page in pages {
            plans.append(makeStandalonePagePlan(
                page: page,
                rendered: pageRenderedContent[page.route] ?? "",
                site: siteContext,
                urlBuilder: urlBuilder
            ))
        }
        if let home {
            plans = plans.filter { $0.route != "/" }
            plans.append(makeHomePlan(
                home: home,
                site: siteContext,
                collections: collections,
                urlBuilder: urlBuilder
            ))
        }
        return injectingData(plans, data: data)
    }

    /// Builds the paginated landing-page plans for the legacy posts path.
    private func landingPlans(
        mapped: [RenderablePost],
        site: [String: Any],
        siteTitle: String,
        siteDescription: String,
        urlBuilder: SiteURLBuilder
    ) -> [PagePlan] {
        let chunks = mapped.chunked(into: postsPerPage)
        let totalPages = max(chunks.count, 1)
        guard chunks.isEmpty == false else {
            return [makeLandingPlan(
                route: "/",
                posts: [],
                page: 1,
                totalPages: 1,
                site: site,
                siteTitle: siteTitle,
                siteDescription: siteDescription,
                urlBuilder: urlBuilder
            )]
        }
        return chunks.enumerated().map { index, chunk in
            let pageNumber = index + 1
            return makeLandingPlan(
                route: pageNumber == 1 ? "/" : "/page/\(pageNumber)/",
                posts: chunk,
                page: pageNumber,
                totalPages: totalPages,
                site: site,
                siteTitle: siteTitle,
                siteDescription: siteDescription,
                urlBuilder: urlBuilder
            )
        }
    }

    /// Returns `plans` with the shared `data` dict merged into each context,
    /// or the plans unchanged when there is no data.
    private func injectingData(_ plans: [PagePlan], data: [String: Any]) -> [PagePlan] {
        guard data.isEmpty == false else { return plans }
        return plans.map { plan in
            var context = plan.context
            context["data"] = data
            return PagePlan(route: plan.route, template: plan.template, context: context)
        }
    }

    private func mapPost(_ post: PostDocument) -> RenderablePost? {
        guard let slug = post.frontMatter.slug, let title = post.frontMatter.title else {
            return nil
        }
        if post.frontMatter.draft == true {
            return nil
        }
        let summary = post.frontMatter.summary ?? "Notes, ideas, and field observations from the journal."
        let date = post.frontMatter.date ?? ""
        return RenderablePost(
            slug: slug,
            title: title,
            summary: summary,
            date: date,
            tags: post.frontMatter.tags ?? [],
            categories: post.frontMatter.categories ?? [],
            canonicalURL: post.frontMatter.normalizedCanonicalURL,
            coverImage: post.frontMatter.coverImage,
            ogImage: post.frontMatter.ogImage,
            tocOptIn: post.frontMatter.toc
        )
    }
}

// swiftlint:disable function_parameter_count
private extension PageContextBuilder {
    func makeLandingPlan(
        route: String,
        posts: [RenderablePost],
        page: Int,
        totalPages: Int,
        site: [String: Any],
        siteTitle: String,
        siteDescription: String,
        urlBuilder: SiteURLBuilder
    ) -> PagePlan {
        let postsContext = posts.map { postCardContext($0, urlBuilder: urlBuilder) }
        let paginationItems: [[String: Any]] = (1...totalPages).map { index in
            return [
                "page": index,
                "href": urlBuilder.link(for: index == 1 ? "/" : "/page/\(index)/"),
                "active": index == page
            ]
        }
        let pageContext: [String: Any] = [
            "type": "landing",
            "title": escapeHTML(siteTitle),
            "description": escapeHTML(siteDescription),
            "canonicalURL": escapeHTML(urlBuilder.compose(route: route)),
            "twitterCard": "summary"
        ]
        let context: [String: Any] = [
            "site": site,
            "page": pageContext,
            "links": [
                "home": urlBuilder.link(for: "/"),
                "archive": urlBuilder.link(for: "/archive/")
            ],
            "posts": postsContext,
            "pagination": [
                "currentPage": page,
                "totalPages": totalPages,
                "items": paginationItems
            ]
        ]
        return PagePlan(route: route, template: "layouts/landing", context: context)
    }

    func makeArchivePlan(
        posts: [RenderablePost],
        site: [String: Any],
        urlBuilder: SiteURLBuilder
    ) -> PagePlan {
        let route = "/archive/"
        let postsContext = posts.map { postCardContext($0, urlBuilder: urlBuilder) }
        let pageContext: [String: Any] = [
            "type": "archive",
            "title": "Archive",
            "description": "Archive of published journal entries.",
            "canonicalURL": escapeHTML(urlBuilder.compose(route: route)),
            "twitterCard": "summary"
        ]
        let context: [String: Any] = [
            "site": site,
            "page": pageContext,
            "links": ["home": urlBuilder.link(for: "/")],
            "posts": postsContext
        ]
        return PagePlan(route: route, template: "layouts/post-list", context: context)
    }

    func makePostPlan(
        post: RenderablePost,
        content: String,
        site: [String: Any],
        urlBuilder: SiteURLBuilder,
        lang: String = "en"
    ) -> PagePlan {
        let route = "/posts/\(post.slug)/"
        let chips = makeTaxonomyChips(tags: post.tags, categories: post.categories, urlBuilder: urlBuilder)
        let annotated = annotateHeadings(html: content, tocOptIn: post.tocOptIn)
        let trimmedCoverImage = post.coverImage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let coverImageContext: [String: Any]? = resolveCoverImage(
            path: trimmedCoverImage,
            alt: post.title,
            urlBuilder: urlBuilder
        )
        let canonicalURL = post.canonicalURL ?? urlBuilder.compose(route: route)
        let twitterCard = coverImageContext == nil ? "summary" : "summary_large_image"

        var pageContext: [String: Any] = [
            "type": "post",
            "title": escapeHTML(post.title),
            "description": escapeHTML(post.summary),
            "date": escapeHTML(post.date),
            "canonicalURL": escapeHTML(canonicalURL),
            "twitterCard": twitterCard,
            "chips": chips,
            "content": annotated.html
        ]
        if let toc = annotated.toc {
            pageContext["toc"] = toc
        }
        if let coverImageContext {
            pageContext["coverImage"] = coverImageContext
        }
        if let ogImageURL = resolveOGImage(
            override: post.ogImage,
            title: post.title,
            subtitle: post.summary,
            lang: lang,
            urlBuilder: urlBuilder
        ) {
            pageContext["ogImage"] = escapeHTML(ogImageURL)
        }
        let readingMinutes = ReadingTime.compute(html: content)
        if readingMinutes > 0 {
            pageContext["readingTime"] = readingMinutes
            pageContext["readMin"] = readingMinutes
            let format = (site["themeCopy"] as? [String: String])?["readingTimeLabel"] ?? "%d min read"
            pageContext["readingTimeLabel"] = escapeHTML(String(format: format, readingMinutes))
        }

        let context: [String: Any] = [
            "site": site,
            "page": pageContext,
            "links": ["home": urlBuilder.link(for: "/")]
        ]
        return PagePlan(route: route, template: "layouts/post", context: context)
    }

    /// Run HeadingExtractor on the rendered body to attach `id` attributes to
    /// every h2/h3 (so anchor links work even without TOC), and return a
    /// nested TOC structure when the page should expose one. TOC shows
    /// when front-matter sets `toc: true` or when the body has at least
    /// three h2s.
    func annotateHeadings(html: String, tocOptIn: Bool?) -> (html: String, toc: [[String: Any]]?) {
        let extracted = HeadingExtractor.extract(html: html)
        let h2Count = extracted.headings.filter { $0.level == 2 }.count
        let shouldExpose = tocOptIn == true || h2Count >= 3
        guard shouldExpose else {
            return (extracted.html, nil)
        }
        return (extracted.html, nestedTOC(from: extracted.headings))
    }

    private func nestedTOC(from headings: [HeadingExtractor.Heading]) -> [[String: Any]] {
        var result: [[String: Any]] = []
        for heading in headings {
            let entry: [String: Any] = [
                "level": heading.level,
                "text": escapeHTML(heading.text),
                "anchor": heading.anchor,
                "children": [[String: Any]]()
            ]
            if heading.level == 2 || result.isEmpty {
                result.append(entry)
            } else {
                var parent = result.removeLast()
                var children = parent["children"] as? [[String: Any]] ?? []
                children.append(entry)
                parent["children"] = children
                result.append(parent)
            }
        }
        return result
    }

    /// Resolve a front-matter `ogImage` override (absolute URL passes
    /// through, project path gets basePath prefixing) or fall back to the
    /// configured OG card resolver. Returns nil when neither yields a URL.
    private func resolveOGImage(
        override: String?,
        title: String,
        subtitle: String,
        lang: String,
        urlBuilder: SiteURLBuilder
    ) -> String? {
        if let override, override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            let trimmed = override.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("://") || trimmed.hasPrefix("//") {
                return trimmed
            }
            if trimmed.hasPrefix("/") {
                return urlBuilder.assetLink(for: trimmed)
            }
            return trimmed
        }
        return ogCardResolver?(title, subtitle, lang)
    }

    /// Resolve a front-matter image path into a coverImage context dict.
    /// Tries the responsive resolver first (returns srcset/srcsetAvif/width
    /// /height/etc when the image lives under static/ or public/); otherwise
    /// falls back to the basic `{src, alt}` shape so external URLs and
    /// projects without an image pipeline still work.
    private func resolveCoverImage(
        path trimmed: String?,
        alt: String,
        urlBuilder: SiteURLBuilder
    ) -> [String: Any]? {
        guard let trimmed, trimmed.isEmpty == false else { return nil }
        if let dict = imageResolver?(trimmed, alt) {
            return dict
        }
        let resolved = trimmed.hasPrefix("/") ? urlBuilder.assetLink(for: trimmed) : trimmed
        return [
            "src": escapeHTML(resolved),
            "alt": escapeHTML(alt)
        ]
    }

    func makeTaxonomyPlans(
        kind: String,
        posts: [RenderablePost],
        site: [String: Any],
        urlBuilder: SiteURLBuilder,
        extractor: (RenderablePost) -> [String]
    ) -> [PagePlan] {
        var grouped: [String: [RenderablePost]] = [:]
        for post in posts {
            for value in extractor(post) {
                grouped[value, default: []].append(post)
            }
        }

        return grouped.keys.sorted().map { key in
            let slug = taxonomySlug(key)
            let route = "/\(kind)/\(slug)/"
            let title = "\(kind.capitalized): \(key)"
            let description = "Archive page for \(kind) \(key)."
            let postsContext = (grouped[key] ?? []).map { postCardContext($0, urlBuilder: urlBuilder) }
            let pageContext: [String: Any] = [
                "type": "taxonomy",
                "kind": kind,
                "label": escapeHTML(key),
                "title": escapeHTML(title),
                "description": escapeHTML(description),
                "canonicalURL": escapeHTML(urlBuilder.compose(route: route)),
                "twitterCard": "summary"
            ]
            let context: [String: Any] = [
                "site": site,
                "page": pageContext,
                "links": ["home": urlBuilder.link(for: "/")],
                "posts": postsContext
            ]
            return PagePlan(route: route, template: "layouts/taxonomy", context: context)
        }
    }

    func postCardContext(_ post: RenderablePost, urlBuilder: SiteURLBuilder) -> [String: Any] {
        var ctx: [String: Any] = [
            "slug": post.slug,
            "title": escapeHTML(post.title),
            "summary": escapeHTML(post.summary),
            "date": escapeHTML(post.date),
            "displayDate": escapeHTML(formatDisplayDate(post.date)),
            "link": urlBuilder.link(for: "/posts/\(post.slug)/"),
            "chips": makeTaxonomyChips(tags: post.tags, categories: post.categories, urlBuilder: urlBuilder)
        ]
        if let primary = post.tags.first {
            ctx["primaryTag"] = escapeHTML(primary)
        }
        if let primaryCategory = post.categories.first {
            ctx["primaryCategory"] = escapeHTML(primaryCategory)
        }
        return ctx
    }

    /// Convert an ISO 8601 / YAML date string into a display-friendly form
    /// matching the prototype ("2026.04.20"). Falls back to the raw value.
    func formatDisplayDate(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "" }
        let prefix = String(trimmed.prefix(10))
        if prefix.count == 10, prefix[prefix.index(prefix.startIndex, offsetBy: 4)] == "-" {
            return prefix.replacingOccurrences(of: "-", with: ".")
        }
        return trimmed
    }

    func makeTaxonomyChips(tags: [String], categories: [String], urlBuilder: SiteURLBuilder) -> [[String: Any]] {
        let tagChips = tags.prefix(3).map { value -> [String: Any] in
            return [
                "label": escapeHTML(value),
                "href": urlBuilder.link(for: "/tags/\(taxonomySlug(value))/")
            ]
        }
        let categoryChips = categories.prefix(2).map { value -> [String: Any] in
            return [
                "label": escapeHTML(value),
                "href": urlBuilder.link(for: "/categories/\(taxonomySlug(value))/")
            ]
        }
        return tagChips + categoryChips
    }

    func makeHomePlan(
        home: HomeConfig,
        site: [String: Any],
        collections: [String: Collection],
        childCollections: [String: ResolvedChildCollection] = [:],
        urlBuilder: SiteURLBuilder,
        lang: String = "en",
        defaultLanguage: String = "en",
        allLanguages: [String] = ["en"],
        baseURL: String = "/"
    ) -> PagePlan {
        let route = "/"
        let langPrefix = (lang == defaultLanguage) ? "" : "/\(lang)"
        let title = (site["title"] as? String) ?? "Home"
        let description = (site["description"] as? String) ?? title

        let featured = homeCollectionCards(
            collectionId: home.featuredCollection,
            count: home.featuredCount ?? 4,
            collections: collections,
            lang: lang,
            defaultLanguage: defaultLanguage,
            urlBuilder: urlBuilder,
            site: site
        )
        let recent = homeCollectionCards(
            collectionId: home.recentCollection,
            count: home.recentCount ?? 3,
            collections: collections,
            lang: lang,
            defaultLanguage: defaultLanguage,
            urlBuilder: urlBuilder,
            site: site
        )
        let building = homeBuildingCards(
            collectionId: home.buildingCollection,
            count: home.buildingCount ?? 3,
            childCollections: childCollections,
            collections: collections,
            lang: lang,
            defaultLanguage: defaultLanguage,
            urlBuilder: urlBuilder,
            site: site
        )

        let pageContext: [String: Any] = [
            "type": "home",
            "title": title,
            "description": description,
            "canonicalURL": escapeHTML(urlBuilder.compose(route: route)),
            "twitterCard": "summary",
            "lang": lang,
            "translations": translationLinks(
                availableLanguages: allLanguages,
                currentLang: lang,
                defaultLanguage: defaultLanguage,
                baseURL: baseURL,
                canonicalRoute: route
            ),
            "hreflangs": hreflangLinks(
                availableLanguages: allLanguages,
                defaultLanguage: defaultLanguage,
                baseURL: baseURL,
                canonicalRoute: route
            )
        ]
        let homeContext = homeBlockContext(home: home, featured: featured, recent: recent, building: building)
        let context: [String: Any] = [
            "site": site,
            "page": pageContext,
            "home": homeContext,
            "links": [
                "home": urlBuilder.link(for: "/"),
                "archive": urlBuilder.link(for: "/archive/")
            ],
            "posts": [],
            "pagination": ["currentPage": 1, "totalPages": 1, "items": []]
        ]
        return PagePlan(route: langPrefix + route, template: "layouts/\(home.template)", context: context)
    }

    /// Builds the card contexts for a home-page collection slot (featured or
    /// recent), best-fitting items to `lang` and capping at `count`.
    private func homeCollectionCards(
        collectionId: String?,
        count: Int,
        collections: [String: Collection],
        lang: String,
        defaultLanguage: String,
        urlBuilder: SiteURLBuilder,
        site: [String: Any]
    ) -> [[String: Any]] {
        guard let collectionId, let collection = collections[collectionId] else { return [] }
        let resolved = bestFitItems(collection.items, lang: lang, defaultLanguage: defaultLanguage)
        let route = normalizedCollectionRoute(collection.config.route)
        return Array(resolved.prefix(count)).map {
            collectionItemCardContext($0, route: route, urlBuilder: urlBuilder, site: site)
        }
    }

    /// Assembles the `home` template block: featured/recent cards, labels, and
    /// optional CTAs/about-links.
    private func homeBlockContext(
        home: HomeConfig,
        featured: [[String: Any]],
        recent: [[String: Any]],
        building: [[String: Any]]
    ) -> [String: Any] {
        var homeContext: [String: Any] = [
            "featured": featured,
            "recent": recent,
            "building": building
        ]
        if let cta = home.heroPrimaryCta {
            homeContext["heroPrimaryCta"] = ctaContext(cta)
        }
        if let cta = home.heroSecondaryCta {
            homeContext["heroSecondaryCta"] = ctaContext(cta)
        }
        homeContext["featuredLabel"] = escapeHTML(home.featuredLabel ?? "Selected work")
        homeContext["recentLabel"] = escapeHTML(home.recentLabel ?? "Recent writing")
        homeContext["buildingLabel"] = escapeHTML(home.buildingLabel ?? "What I'm building")
        homeContext["aboutEyebrow"] = escapeHTML(home.aboutEyebrow ?? "About")
        if let cta = home.featuredCta {
            homeContext["featuredCta"] = ctaContext(cta)
        }
        if let cta = home.recentCta {
            homeContext["recentCta"] = ctaContext(cta)
        }
        if let cta = home.buildingCta {
            homeContext["buildingCta"] = ctaContext(cta)
        }
        if let links = home.aboutLinks, links.isEmpty == false {
            homeContext["aboutLinks"] = links.map { ctaContext($0) }
        }
        return homeContext
    }

    /// Hero headline with `*word*` → `<em class="accent-em">word</em>` transform.
    /// Falls back to the site title (escaped) when no headline is configured.
    func heroHeadline(for siteConfig: SiteConfig, overlay: TranslationOverlay? = nil) -> String {
        let raw = overlay?.heroHeadline ?? siteConfig.heroHeadline ?? siteConfig.title
        return renderAccentItalics(raw)
    }

    /// Splits `text` on `*…*` markers; returns escaped HTML with the inner
    /// segments wrapped in `<em class="accent-em">`. Unbalanced asterisks
    /// degrade gracefully — a stray `*` is rendered as a literal asterisk.
    func renderAccentItalics(_ text: String) -> String {
        var result = ""
        var inAccent = false
        var buffer = ""
        for character in text {
            if character == "*" {
                let escaped = escapeHTML(buffer)
                if inAccent {
                    result += "<em class=\"accent-em\">\(escaped)</em>"
                } else {
                    result += escaped
                }
                buffer = ""
                inAccent.toggle()
                continue
            }
            buffer.append(character)
        }
        if buffer.isEmpty == false {
            // Trailing buffer — if we ended mid-accent, keep the literal asterisk + content.
            let escaped = escapeHTML(buffer)
            result += inAccent ? "*\(escaped)" : escaped
        } else if inAccent {
            // Open marker with no closing one and no content; emit the asterisk literally.
            result += "*"
        }
        return result
    }

    /// Footer call-to-action strings — escaped, with theme defaults when
    /// `siteConfig.footerCta` is unset or only partially specified. The
    /// `overlay` (per-language translation) wins over `siteConfig` field-by-
    /// field — set fields override; nil fields fall back.
    func footerCtaContext(for siteConfig: SiteConfig, overlay: TranslationOverlay? = nil) -> [String: String] {
        let base = siteConfig.footerCta
        let over = overlay?.footerCta
        let eyebrow = over?.eyebrow ?? base?.eyebrow ?? "Get in touch"
        let headline = over?.headline ?? base?.headline ?? "Quietly open to good work."
        return [
            "eyebrow": escapeHTML(eyebrow),
            "headline": escapeHTML(headline)
        ]
    }

    /// Theme-level chrome strings — escaped, with the quiet-theme English
    /// defaults filled in for any field the site config omits. Overlay
    /// fields (per-language) win over base fields.
    func themeCopyContext(for siteConfig: SiteConfig, overlay: TranslationOverlay? = nil) -> [String: String] {
        let base = siteConfig.themeCopy
        let over = overlay?.themeCopy
        return [
            "workCardCta": escapeHTML(over?.workCardCta ?? base?.workCardCta ?? "Read case study"),
            "caseStudyBack": escapeHTML(over?.caseStudyBack ?? base?.caseStudyBack ?? "← All work"),
            "caseStudyNextLabel": escapeHTML(over?.caseStudyNextLabel ?? base?.caseStudyNextLabel ?? "Next"),
            "caseStudyNextFallbackCta": escapeHTML(
                over?.caseStudyNextFallbackCta ?? base?.caseStudyNextFallbackCta ?? "Read case study"
            ),
            "aboutEyebrow": escapeHTML(over?.aboutEyebrow ?? base?.aboutEyebrow ?? "04 · About"),
            "aboutResumeCta": escapeHTML(over?.aboutResumeCta ?? base?.aboutResumeCta ?? "Read the résumé"),
            "aboutEmailCta": escapeHTML(over?.aboutEmailCta ?? base?.aboutEmailCta ?? "Email me"),
            "postBack": escapeHTML(over?.postBack ?? base?.postBack ?? "← All entries"),
            "postMoreCta": escapeHTML(over?.postMoreCta ?? base?.postMoreCta ?? "More writing"),
            "postReplyEmailCta": escapeHTML(over?.postReplyEmailCta ?? base?.postReplyEmailCta ?? "Reply by email"),
            "postMinRead": escapeHTML(over?.postMinRead ?? base?.postMinRead ?? "min read"),
            "readingTimeLabel": over?.readingTimeLabel ?? base?.readingTimeLabel ?? "%d min read",
            "buildingBack": escapeHTML(over?.buildingBack ?? base?.buildingBack ?? "← The workshop"),
            "buildingUpdates": escapeHTML(over?.buildingUpdates ?? base?.buildingUpdates ?? "Updates"),
            "buildingNextLabel": escapeHTML(over?.buildingNextLabel ?? base?.buildingNextLabel ?? "Next"),
            "buildingNextCta": escapeHTML(over?.buildingNextCta ?? base?.buildingNextCta ?? "See the build log"),
            "updateNewer": escapeHTML(over?.updateNewer ?? base?.updateNewer ?? "Newer"),
            "updateOlder": escapeHTML(over?.updateOlder ?? base?.updateOlder ?? "Older"),
            "notFoundEyebrow": escapeHTML(over?.notFoundEyebrow ?? base?.notFoundEyebrow ?? "404 · NOT FOUND"),
            "notFoundHeadline": escapeHTML(
                over?.notFoundHeadline ?? base?.notFoundHeadline ?? "This page is in another castle."
            ),
            "notFoundBody": escapeHTML(
                over?.notFoundBody
                    ?? base?.notFoundBody
                    ?? "Or it never existed. Or it's still drafted in a markdown file on my laptop. Try the home page."
            ),
            "notFoundCta": escapeHTML(over?.notFoundCta ?? base?.notFoundCta ?? "Back home"),
            "themeToggleLabel": escapeHTML(over?.themeToggleLabel ?? base?.themeToggleLabel ?? "Toggle theme")
        ]
    }

    /// Renders a `HomeCta` as an escaped {label, href} dict for templates.
    func ctaContext(_ cta: HomeCta) -> [String: String] {
        ["label": escapeHTML(cta.label), "href": escapeHTML(cta.href)]
    }

    /// First letter of the author's name (or site title), uppercased. Used by
    /// the quiet theme's brand mark.
    func brandInitial(for siteConfig: SiteConfig) -> String {
        let source = siteConfig.author?.name ?? siteConfig.title
        guard let first = source.trimmingCharacters(in: .whitespacesAndNewlines).first else { return "·" }
        return String(first).uppercased()
    }

    /// Default footer copyright line: "© <year> · <author or title>". Themes
    /// can override via the `head:` HTML fragment if they want something else.
    func copyrightLine(for siteConfig: SiteConfig) -> String {
        let year = Calendar(identifier: .gregorian).component(.year, from: Date())
        let owner = siteConfig.author?.name ?? siteConfig.title
        return escapeHTML("© \(year) · \(owner)")
    }

    func authorContext(
        _ author: AuthorConfig,
        overlay: AuthorOverlay? = nil,
        urlBuilder: SiteURLBuilder
    ) -> [String: Any] {
        var context: [String: Any] = [
            "name": escapeHTML(author.name)
        ]
        let role = overlay?.role ?? author.role
        let location = overlay?.location ?? author.location
        let tagline = overlay?.tagline ?? author.tagline
        let timezone = overlay?.timezone ?? author.timezone
        let heroSummary = overlay?.heroSummary ?? author.heroSummary
        let aboutTeaser = overlay?.aboutTeaser ?? author.aboutTeaser
        if let role { context["role"] = escapeHTML(role) }
        if let location { context["location"] = escapeHTML(location) }
        if let email = author.email { context["email"] = escapeHTML(email) }
        if let tagline { context["tagline"] = escapeHTML(tagline) }
        if let timezone { context["timezone"] = escapeHTML(timezone) }
        if let heroSummary { context["heroSummary"] = escapeHTML(heroSummary) }
        if let aboutTeaser { context["aboutTeaser"] = escapeHTML(aboutTeaser) }
        if let portrait = author.portrait?.trimmingCharacters(in: .whitespacesAndNewlines), portrait.isEmpty == false {
            context["portrait"] = escapeHTML(portrait.hasPrefix("/") ? urlBuilder.assetLink(for: portrait) : portrait)
        }
        if let social = author.social, social.isEmpty == false {
            context["social"] = social.map { link -> [String: String] in
                [
                    "label": escapeHTML(link.label),
                    "url": link.url
                ]
            }
        }
        return context
    }

    /// For each unique slug in `items`, returns the variant best suited to
    /// the requested language: the lang variant if it exists, otherwise the
    /// default-language variant, otherwise whatever's available. Preserves
    /// the input ordering of first appearance per slug.
    func bestFitItems(_ items: [CollectionItem], lang: String, defaultLanguage: String) -> [CollectionItem] {
        var seen = Set<String>()
        var resolved: [CollectionItem] = []
        for item in items where seen.contains(item.slug) == false {
            seen.insert(item.slug)
            if let langItem = items.first(where: { $0.slug == item.slug && $0.lang == lang }) {
                resolved.append(langItem)
            } else if let defaultItem = items.first(where: { $0.slug == item.slug && $0.lang == defaultLanguage }) {
                resolved.append(defaultItem)
            } else {
                resolved.append(item)
            }
        }
        return resolved
    }

    /// Same as `bestFitItems` but for standalone pages, keyed by route.
    func bestFitPages(_ pages: [Page], lang: String, defaultLanguage: String) -> [Page] {
        var seen = Set<String>()
        var resolved: [Page] = []
        for page in pages where seen.contains(page.route) == false {
            seen.insert(page.route)
            if let langPage = pages.first(where: { $0.route == page.route && $0.lang == lang }) {
                resolved.append(langPage)
            } else if let defaultPage = pages.first(where: { $0.route == page.route && $0.lang == defaultLanguage }) {
                resolved.append(defaultPage)
            } else {
                resolved.append(page)
            }
        }
        return resolved
    }

    /// Returns the collection config with translatable fields (eyebrow,
    /// headline, lede) overridden from the overlay when present.
    func applyOverlay(to config: CollectionConfig, overlay: TranslationOverlay?) -> CollectionConfig {
        guard let collectionOverlay = overlay?.collections?.first(where: { $0.id == config.id }) else {
            return config
        }
        var copy = config
        if let eyebrow = collectionOverlay.eyebrow { copy.eyebrow = eyebrow }
        if let headline = collectionOverlay.headline { copy.headline = headline }
        if let lede = collectionOverlay.lede { copy.lede = lede }
        return copy
    }

    /// Returns the home config with translatable fields (CTAs, section
    /// labels, about-teaser links) overridden from the overlay when present.
    /// Structural fields (template, featuredCollection, etc.) are unchanged.
    func applyOverlay(to config: HomeConfig, overlay: TranslationOverlay?) -> HomeConfig {
        guard let homeOverlay = overlay?.home else { return config }
        var copy = config
        if let cta = homeOverlay.heroPrimaryCta { copy.heroPrimaryCta = cta }
        if let cta = homeOverlay.heroSecondaryCta { copy.heroSecondaryCta = cta }
        if let label = homeOverlay.featuredLabel { copy.featuredLabel = label }
        if let cta = homeOverlay.featuredCta { copy.featuredCta = cta }
        if let label = homeOverlay.recentLabel { copy.recentLabel = label }
        if let cta = homeOverlay.recentCta { copy.recentCta = cta }
        if let label = homeOverlay.buildingLabel { copy.buildingLabel = label }
        if let cta = homeOverlay.buildingCta { copy.buildingCta = cta }
        if let eyebrow = homeOverlay.aboutEyebrow { copy.aboutEyebrow = eyebrow }
        if let links = homeOverlay.aboutLinks { copy.aboutLinks = links }
        return copy
    }

    func makeStandalonePagePlan(
        page: Page,
        rendered: String,
        site: [String: Any],
        urlBuilder: SiteURLBuilder,
        lang: String = "en",
        defaultLanguage: String = "en",
        baseURL: String = "/"
    ) -> PagePlan {
        let title = page.title ?? humanize(routeAsTitle: page.route)
        let description = page.summary ?? title
        var pageContext: [String: Any] = [
            "type": "page",
            "title": escapeHTML(title),
            "description": escapeHTML(description),
            "canonicalURL": escapeHTML(urlBuilder.compose(route: page.route)),
            "twitterCard": "summary",
            "layout": page.layout,
            "content": rendered,
            "frontMatter": page.frontMatter,
            "lang": lang,
            "translations": translationLinks(
                availableLanguages: page.availableLanguages,
                currentLang: lang,
                defaultLanguage: defaultLanguage,
                baseURL: baseURL,
                canonicalRoute: page.route
            ),
            "hreflangs": hreflangLinks(
                availableLanguages: page.availableLanguages,
                defaultLanguage: defaultLanguage,
                baseURL: baseURL,
                canonicalRoute: page.route
            )
        ]
        // Mirror collection-list pages: surface `eyebrow` from front-matter
        // as a top-level `page.eyebrow` so every layout can use the same
        // template variable regardless of the page's source.
        if let eyebrow = page.frontMatter["eyebrow"] as? String {
            pageContext["eyebrow"] = escapeHTML(eyebrow)
        }
        let prefixedRoute = (lang == defaultLanguage ? "" : "/\(lang)") + page.route
        let context: [String: Any] = [
            "site": site,
            "page": pageContext,
            "links": ["home": urlBuilder.link(for: "/")]
        ]
        return PagePlan(route: prefixedRoute, template: "layouts/\(page.layout)", context: context)
    }

    /// Returns an array of `{lang, href}` dicts pointing to the same
    /// canonical content in every OTHER language available. Used by the
    /// language switcher in the top bar — does NOT include the current
    /// language (the user is already on it).
    func translationLinks(
        availableLanguages: [String],
        currentLang: String,
        defaultLanguage: String,
        baseURL: String,
        canonicalRoute: String
    ) -> [[String: String]] {
        availableLanguages
            .filter { $0 != currentLang }
            .map { otherLang -> [String: String] in
                hreflangEntry(
                    lang: otherLang,
                    defaultLanguage: defaultLanguage,
                    baseURL: baseURL,
                    canonicalRoute: canonicalRoute
                )
            }
    }

    /// Returns hreflang entries for SEO: self-reference + every other
    /// available language + an `x-default` entry pointing to the
    /// default-language URL. Search engines use this to map readers to
    /// the right localized version.
    func hreflangLinks(
        availableLanguages: [String],
        defaultLanguage: String,
        baseURL: String,
        canonicalRoute: String
    ) -> [[String: String]] {
        var links: [[String: String]] = availableLanguages.map { lang in
            hreflangEntry(
                lang: lang,
                defaultLanguage: defaultLanguage,
                baseURL: baseURL,
                canonicalRoute: canonicalRoute
            )
        }
        let defaultBuilder = SiteURLBuilder(baseURL: baseURL, langPrefix: "")
        links.append([
            "lang": "x-default",
            "href": defaultBuilder.link(for: canonicalRoute)
        ])
        return links
    }

    private func hreflangEntry(
        lang: String,
        defaultLanguage: String,
        baseURL: String,
        canonicalRoute: String
    ) -> [String: String] {
        let prefix = (lang == defaultLanguage) ? "" : lang
        let urlBuilder = SiteURLBuilder(baseURL: baseURL, langPrefix: prefix)
        return [
            "lang": lang,
            "href": urlBuilder.link(for: canonicalRoute)
        ]
    }

    /// Best-effort title from a route ("/about/" → "About"). Used only when
    /// the page front matter omits a `title`.
    func humanize(routeAsTitle route: String) -> String {
        let trimmed = route.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmed.isEmpty { return "Home" }
        let last = trimmed.split(separator: "/").last.map(String.init) ?? trimmed
        return last
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    func makeCollectionPlans(
        collection: Collection,
        rendered: [String: String],
        updatesBySlug: [String: [[String: Any]]]? = nil,
        site: [String: Any],
        urlBuilder: SiteURLBuilder,
        lang: String = "en",
        defaultLanguage: String = "en",
        allLanguages: [String]? = nil,
        baseURL: String = "/"
    ) -> [PagePlan] {
        let listLanguages = allLanguages ?? [lang]
        let route = normalizedCollectionRoute(collection.config.route)
        let detailTemplate = collection.config.detailTemplate ?? "layouts/post"
        let langPrefix = (lang == defaultLanguage) ? "" : "/\(lang)"

        var plans: [PagePlan] = [
            makeCollectionListPlan(
                collection: collection,
                updatesBySlug: updatesBySlug,
                site: site,
                urlBuilder: urlBuilder,
                route: route,
                langPrefix: langPrefix,
                lang: lang,
                defaultLanguage: defaultLanguage,
                listLanguages: listLanguages,
                baseURL: baseURL
            )
        ]
        for (index, item) in collection.items.enumerated() {
            // Non-nil (possibly empty) when this is a parent collection, so the
            // detail page can render the timeline + status even with no updates.
            let itemUpdates: [[String: Any]]? = (updatesBySlug != nil)
                ? (updatesBySlug?[item.slug] ?? [])
                : nil
            plans.append(makeCollectionDetailPlan(
                item: item,
                index: index,
                collection: collection,
                rendered: rendered,
                updates: itemUpdates,
                site: site,
                urlBuilder: urlBuilder,
                route: route,
                detailTemplate: detailTemplate,
                langPrefix: langPrefix,
                lang: lang,
                defaultLanguage: defaultLanguage,
                baseURL: baseURL
            ))
        }
        plans.append(contentsOf: makeCollectionTaxonomyPlans(
            collection: collection,
            site: site,
            urlBuilder: urlBuilder,
            route: route,
            langPrefix: langPrefix
        ))
        return plans
    }

    /// Builds the listing-page plan for a collection.
    private func makeCollectionListPlan(
        collection: Collection,
        updatesBySlug: [String: [[String: Any]]]? = nil,
        site: [String: Any],
        urlBuilder: SiteURLBuilder,
        route: String,
        langPrefix: String,
        lang: String,
        defaultLanguage: String,
        listLanguages: [String],
        baseURL: String
    ) -> PagePlan {
        let listTemplate = collection.config.listTemplate ?? "layouts/post-list"
        let itemContexts = collection.items.map {
            collectionItemCardContext(
                $0, route: route, updatesBySlug: updatesBySlug, urlBuilder: urlBuilder, site: site
            )
        }
        let listTitle = collection.config.headline ?? collection.config.id.capitalized
        var listPageContext: [String: Any] = [
            "type": "collection-list",
            "title": escapeHTML(listTitle),
            "headline": renderAccentItalics(listTitle),
            "description": escapeHTML(collection.config.lede ?? "\(collection.config.id.capitalized) listing"),
            "canonicalURL": escapeHTML(urlBuilder.compose(route: route)),
            "twitterCard": "summary",
            "lang": lang,
            "translations": translationLinks(
                availableLanguages: listLanguages,
                currentLang: lang,
                defaultLanguage: defaultLanguage,
                baseURL: baseURL,
                canonicalRoute: route
            ),
            "hreflangs": hreflangLinks(
                availableLanguages: listLanguages,
                defaultLanguage: defaultLanguage,
                baseURL: baseURL,
                canonicalRoute: route
            )
        ]
        if let eyebrow = collection.config.eyebrow {
            listPageContext["eyebrow"] = escapeHTML(eyebrow)
        }
        if let lede = collection.config.lede {
            listPageContext["lede"] = escapeHTML(lede)
        }
        let listContext: [String: Any] = [
            "site": site,
            "page": listPageContext,
            "links": ["home": urlBuilder.link(for: "/")],
            "collection": [
                "id": collection.config.id,
                "route": urlBuilder.link(for: route)
            ],
            "posts": itemContexts,
            "items": itemContexts
        ]
        return PagePlan(route: langPrefix + route, template: listTemplate, context: listContext)
    }

    /// Builds the detail-page plan for one collection item, including reading
    /// time, optional front-matter fields, and the wrap-around "next" sibling.
    private func makeCollectionDetailPlan(
        item: CollectionItem,
        index: Int,
        collection: Collection,
        rendered: [String: String],
        updates: [[String: Any]]? = nil,
        site: [String: Any],
        urlBuilder: SiteURLBuilder,
        route: String,
        detailTemplate: String,
        langPrefix: String,
        lang: String,
        defaultLanguage: String,
        baseURL: String
    ) -> PagePlan {
        let detailRoute = "\(route)\(item.slug)/"
        let pageContext = collectionDetailPageContext(
            item: item,
            site: site,
            urlBuilder: urlBuilder,
            detailRoute: detailRoute,
            taxonomies: collection.config.resolvedTaxonomies,
            collectionRoute: route,
            rendered: rendered,
            updates: updates,
            lang: lang,
            defaultLanguage: defaultLanguage,
            baseURL: baseURL
        )

        // Wrap-around "next" sibling — used by the case-study layout's
        // bottom navigation. Skipped when the collection has only one item.
        var collectionContext: [String: Any] = [
            "id": collection.config.id,
            "route": urlBuilder.link(for: route)
        ]
        if let next = nextSiblingContext(
            items: collection.items,
            index: index,
            route: route,
            urlBuilder: urlBuilder
        ) {
            collectionContext["next"] = next
        }

        let context: [String: Any] = [
            "site": site,
            "page": pageContext,
            "links": ["home": urlBuilder.link(for: "/")],
            "collection": collectionContext
        ]
        return PagePlan(route: langPrefix + detailRoute, template: detailTemplate, context: context)
    }

    /// Builds the `page` context for a collection-detail page: SEO fields,
    /// reading time, content, and optional front-matter-derived fields.
    private func collectionDetailPageContext(
        item: CollectionItem,
        site: [String: Any],
        urlBuilder: SiteURLBuilder,
        detailRoute: String,
        taxonomies: [String],
        collectionRoute: String,
        rendered: [String: String],
        updates: [[String: Any]]? = nil,
        lang: String,
        defaultLanguage: String,
        baseURL: String
    ) -> [String: Any] {
        let chips = makeCollectionTaxonomyChips(
            item: item,
            taxonomies: taxonomies,
            collectionRoute: collectionRoute,
            urlBuilder: urlBuilder
        )
        let trimmedCoverImage = item.coverImage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawDetailHTML = rendered[item.slug] ?? ""
        let detailReadingMinutes = ReadingTime.compute(html: rawDetailHTML.isEmpty ? item.body : rawDetailHTML)
        let detailLabel: String? = {
            guard detailReadingMinutes > 0 else { return nil }
            let format = (site["themeCopy"] as? [String: String])?["readingTimeLabel"] ?? "%d min read"
            return escapeHTML(String(format: format, detailReadingMinutes))
        }()
        let annotatedDetail = annotateHeadings(html: rawDetailHTML, tocOptIn: item.frontMatter["toc"] as? Bool)
        var pageContext: [String: Any] = [
            "type": "collection-detail",
            "title": escapeHTML(item.title),
            "description": escapeHTML(item.summary ?? item.title),
            "summary": escapeHTML(item.summary ?? ""),
            "date": escapeHTML(item.date ?? ""),
            "displayDate": escapeHTML(formatDisplayDate(item.date ?? "")),
            "readMin": detailReadingMinutes,
            "readingTime": detailReadingMinutes,
            "canonicalURL": escapeHTML(item.normalizedCanonicalURL ?? urlBuilder.compose(route: detailRoute)),
            "twitterCard": (trimmedCoverImage?.isEmpty == false) ? "summary_large_image" : "summary",
            "chips": chips,
            "content": annotatedDetail.html,
            "frontMatter": item.frontMatter,
            "lang": lang,
            "translations": translationLinks(
                availableLanguages: item.availableLanguages,
                currentLang: lang,
                defaultLanguage: defaultLanguage,
                baseURL: baseURL,
                canonicalRoute: detailRoute
            ),
            "hreflangs": hreflangLinks(
                availableLanguages: item.availableLanguages,
                defaultLanguage: defaultLanguage,
                baseURL: baseURL,
                canonicalRoute: detailRoute
            )
        ]
        if let detailLabel {
            pageContext["readingTimeLabel"] = detailLabel
        }
        if let detailTOC = annotatedDetail.toc {
            pageContext["toc"] = detailTOC
        }
        applyDetailFrontMatter(
            to: &pageContext,
            item: item,
            trimmedCoverImage: trimmedCoverImage,
            urlBuilder: urlBuilder
        )
        // Parent collections (those with a child/updates collection) carry a
        // non-nil `updates` array — possibly empty — and gain a status + a
        // last-activity summary derived from the newest update.
        if let updates {
            pageContext["updates"] = updates
            pageContext["updateCount"] = updates.count
            pageContext["status"] = escapeHTML((item.frontMatter["status"] as? String) ?? "active")
            if let newest = updates.first {
                if let relative = newest["relativeDate"] { pageContext["relativeUpdated"] = relative }
                if let display = newest["displayDate"] { pageContext["lastUpdated"] = display }
            }
        }
        return pageContext
    }

    /// Merges optional collection-detail front-matter fields into `pageContext`.
    private func applyDetailFrontMatter(
        to pageContext: inout [String: Any],
        item: CollectionItem,
        trimmedCoverImage: String?,
        urlBuilder: SiteURLBuilder
    ) {
        if let primary = item.tags?.first {
            pageContext["primaryTag"] = escapeHTML(primary)
        }
        if let year = item.frontMatter["year"] {
            pageContext["year"] = String(describing: year)
        }
        if let org = item.frontMatter["org"] as? String {
            pageContext["org"] = escapeHTML(org)
        }
        if let role = item.frontMatter["role"] as? String {
            pageContext["role"] = escapeHTML(role)
        }
        if let brand = item.frontMatter["brand"] as? String {
            pageContext["brand"] = brand
        }
        if let coverContext = resolveCoverImage(
            path: trimmedCoverImage,
            alt: item.title,
            urlBuilder: urlBuilder
        ) {
            pageContext["coverImage"] = coverContext
        }
    }

    /// Builds the wrap-around "next" sibling context, or nil for a single-item
    /// collection.
    private func nextSiblingContext(
        items: [CollectionItem],
        index: Int,
        route: String,
        urlBuilder: SiteURLBuilder
    ) -> [String: Any]? {
        guard items.count > 1 else { return nil }
        let nextItem = items[(index + 1) % items.count]
        var next: [String: Any] = [
            "title": escapeHTML(nextItem.title),
            "link": urlBuilder.link(for: "\(route)\(nextItem.slug)/")
        ]
        if let nextOrg = nextItem.frontMatter["org"] as? String {
            next["org"] = escapeHTML(nextOrg)
        }
        if let nextYear = nextItem.frontMatter["year"] {
            next["year"] = String(describing: nextYear)
        }
        return next
    }

    /// Builds the per-taxonomy archive plans for a collection.
    private func makeCollectionTaxonomyPlans(
        collection: Collection,
        site: [String: Any],
        urlBuilder: SiteURLBuilder,
        route: String,
        langPrefix: String
    ) -> [PagePlan] {
        var plans: [PagePlan] = []
        for taxonomy in collection.config.resolvedTaxonomies {
            let extractor = taxonomyExtractor(for: taxonomy)
            var grouped: [String: [CollectionItem]] = [:]
            for item in collection.items {
                for value in extractor(item) {
                    grouped[value, default: []].append(item)
                }
            }
            for key in grouped.keys.sorted() {
                let slug = taxonomySlug(key)
                let taxRoute = "\(route)\(taxonomy)/\(slug)/"
                let cards = (grouped[key] ?? []).map {
                    collectionItemCardContext($0, route: route, urlBuilder: urlBuilder, site: site)
                }
                let pageContext: [String: Any] = [
                    "type": "collection-taxonomy",
                    "kind": taxonomy,
                    "label": escapeHTML(key),
                    "title": escapeHTML("\(taxonomy.capitalized): \(key)"),
                    "description": escapeHTML("Archive page for \(taxonomy) \(key)."),
                    "canonicalURL": escapeHTML(urlBuilder.compose(route: taxRoute)),
                    "twitterCard": "summary"
                ]
                let taxContext: [String: Any] = [
                    "site": site,
                    "page": pageContext,
                    "links": ["home": urlBuilder.link(for: "/")],
                    "collection": [
                        "id": collection.config.id,
                        "route": urlBuilder.link(for: route)
                    ],
                    "posts": cards,
                    "items": cards
                ]
                plans.append(PagePlan(route: langPrefix + taxRoute, template: "layouts/taxonomy", context: taxContext))
            }
        }
        return plans
    }

    /// Returns the value-extraction closure for a collection taxonomy kind.
    private func taxonomyExtractor(for taxonomy: String) -> (CollectionItem) -> [String] {
        switch taxonomy {
        case "tags":
            return { $0.tags ?? [] }
        case "categories":
            return { $0.categories ?? [] }
        default:
            return { item in
                if let array = item.frontMatter[taxonomy] as? [String] { return array }
                if let array = item.frontMatter[taxonomy] as? [Any] { return array.compactMap { $0 as? String } }
                return []
            }
        }
    }

    func collectionItemCardContext(
        _ item: CollectionItem,
        route: String,
        updatesBySlug: [String: [[String: Any]]]? = nil,
        urlBuilder: SiteURLBuilder,
        site: [String: Any] = [:]
    ) -> [String: Any] {
        let detailRoute = "\(route)\(item.slug)/"
        let minutes = estimatedReadingTime(forBody: item.body)
        var ctx: [String: Any] = [
            "slug": item.slug,
            "title": escapeHTML(item.title),
            "summary": escapeHTML(item.summary ?? ""),
            "blurb": escapeHTML(item.summary ?? ""),
            "date": escapeHTML(item.date ?? ""),
            "displayDate": escapeHTML(formatDisplayDate(item.date ?? "")),
            "link": urlBuilder.link(for: detailRoute),
            "chips": [],
            "frontMatter": item.frontMatter,
            "readMin": minutes
        ]
        if minutes > 0 {
            let format = (site["themeCopy"] as? [String: String])?["readingTimeLabel"] ?? "%d min read"
            ctx["readingTimeLabel"] = escapeHTML(String(format: format, minutes))
        }
        if let primary = item.tags?.first {
            ctx["primaryTag"] = escapeHTML(primary)
        }
        if let year = item.frontMatter["year"] {
            ctx["year"] = String(describing: year)
        }
        if let org = item.frontMatter["org"] as? String {
            ctx["org"] = escapeHTML(org)
        }
        if let role = item.frontMatter["role"] as? String {
            ctx["role"] = escapeHTML(role)
        }
        if let brand = item.frontMatter["brand"] as? String {
            ctx["brand"] = brand
        }
        if let coverPath = resolvedCoverImage(for: item, urlBuilder: urlBuilder) {
            ctx["coverImage"] = coverPath
        }
        // Parent-collection cards (building index, home) get a capped update
        // timeline plus status + recency so they can signal momentum.
        if let updatesBySlug {
            let rows = updatesBySlug[item.slug] ?? []
            ctx["updates"] = Array(rows.prefix(3))
            ctx["updateCount"] = rows.count
            ctx["status"] = escapeHTML((item.frontMatter["status"] as? String) ?? "active")
            if let newest = rows.first {
                if let relative = newest["relativeDate"] { ctx["relativeUpdated"] = relative }
                if let display = newest["displayDate"] { ctx["lastUpdated"] = display }
            }
        }
        return ctx
    }

    /// Resolve the card's cover image: prefer explicit `coverImage`, otherwise fall back
    /// to the first `shots` entry. Always returns a renderable URL string.
    private func resolvedCoverImage(for item: CollectionItem, urlBuilder: SiteURLBuilder) -> String? {
        if let cover = item.coverImage?.trimmingCharacters(in: .whitespacesAndNewlines), cover.isEmpty == false {
            return escapeHTML(cover.hasPrefix("/") ? urlBuilder.assetLink(for: cover) : cover)
        }
        if let shots = item.frontMatter["shots"] as? [Any], let first = shots.first as? String {
            let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                return escapeHTML(trimmed.hasPrefix("/") ? urlBuilder.assetLink(for: trimmed) : trimmed)
            }
        }
        return nil
    }

    /// Coarse word-count-based reading-time estimate (200 wpm).
    /// Returns at least 1 for non-empty bodies.
    private func estimatedReadingTime(forBody body: String) -> Int {
        ReadingTime.compute(html: body)
    }

    func makeCollectionTaxonomyChips(
        item: CollectionItem,
        taxonomies: [String],
        collectionRoute: String,
        urlBuilder: SiteURLBuilder
    ) -> [[String: Any]] {
        var chips: [[String: Any]] = []
        for taxonomy in taxonomies {
            let values: [String]
            switch taxonomy {
            case "tags": values = item.tags ?? []
            case "categories": values = item.categories ?? []
            default:
                if let array = item.frontMatter[taxonomy] as? [String] {
                    values = array
                } else if let array = item.frontMatter[taxonomy] as? [Any] {
                    values = array.compactMap { $0 as? String }
                } else {
                    values = []
                }
            }
            for value in values {
                chips.append([
                    "label": escapeHTML(value),
                    "href": urlBuilder.link(for: "\(collectionRoute)\(taxonomy)/\(taxonomySlug(value))/")
                ])
            }
        }
        return chips
    }

    /// Resolves every child collection against its parent for one language:
    /// groups child items under their parent slug (newest first), records
    /// parent titles, and flags orphans (a `parentField` matching no parent).
    /// Returned keyed both by parent id and child id for the two consumers.
    private func resolveChildCollections(
        configs: [CollectionConfig],
        collections: [String: Collection],
        lang: String,
        defaultLanguage: String
    ) -> (byParentId: [String: ResolvedChildCollection], byChildId: [String: ResolvedChildCollection]) {
        var byParentId: [String: ResolvedChildCollection] = [:]
        var byChildId: [String: ResolvedChildCollection] = [:]
        for config in configs where config.isChild {
            guard let parentId = config.parent,
                  let parentConfig = configs.first(where: { $0.id == parentId }),
                  let parentCollection = collections[parentId],
                  let childCollection = collections[config.id] else { continue }
            let parentItems = bestFitItems(parentCollection.items, lang: lang, defaultLanguage: defaultLanguage)
            var parentTitles: [String: String] = [:]
            for item in parentItems { parentTitles[item.slug] = item.title }
            let validSlugs = Set(parentItems.map { $0.slug })

            let childItems = bestFitItems(childCollection.items, lang: lang, defaultLanguage: defaultLanguage)
            let field = config.resolvedParentField
            var grouped: [String: [CollectionItem]] = [:]
            var orphans: [CollectionItem] = []
            var valid: [CollectionItem] = []
            for item in childItems {
                guard let parentSlug = item.frontMatter[field] as? String, validSlugs.contains(parentSlug) else {
                    orphans.append(item)
                    continue
                }
                grouped[parentSlug, default: []].append(item)
                valid.append(item)
            }
            let byDateDesc: ([CollectionItem]) -> [CollectionItem] = { items in
                items.sorted { ($0.date ?? "") > ($1.date ?? "") }
            }
            let resolved = ResolvedChildCollection(
                childConfig: config,
                parentConfig: parentConfig,
                parentTitles: parentTitles,
                itemsByParentSlug: grouped.mapValues(byDateDesc),
                orphans: orphans,
                recentItems: byDateDesc(valid)
            )
            byParentId[parentId] = resolved
            byChildId[config.id] = resolved
        }
        return (byParentId, byChildId)
    }

    /// Builds the per-parent-slug timeline (each a list of update row contexts,
    /// newest first) used by parent list cards and parent detail pages.
    private func buildParentTimeline(
        _ resolved: ResolvedChildCollection,
        urlBuilder: SiteURLBuilder
    ) -> [String: [[String: Any]]] {
        let parentRoute = normalizedCollectionRoute(resolved.parentConfig.route)
        var timeline: [String: [[String: Any]]] = [:]
        for (parentSlug, items) in resolved.itemsByParentSlug {
            timeline[parentSlug] = items.map {
                updateRowContext($0, parentRoute: parentRoute, parentSlug: parentSlug, urlBuilder: urlBuilder)
            }
        }
        return timeline
    }

    /// One update's context as a timeline row / card: title, nested link, dates,
    /// relative recency, and optional status.
    private func updateRowContext(
        _ item: CollectionItem,
        parentRoute: String,
        parentSlug: String,
        urlBuilder: SiteURLBuilder
    ) -> [String: Any] {
        var ctx: [String: Any] = [
            "slug": item.slug,
            "title": escapeHTML(item.title),
            "summary": escapeHTML(item.summary ?? ""),
            "blurb": escapeHTML(item.summary ?? ""),
            "date": escapeHTML(item.date ?? ""),
            "displayDate": escapeHTML(formatDisplayDate(item.date ?? "")),
            "relativeDate": escapeHTML(relativeDate(item.date ?? "")),
            "link": urlBuilder.link(for: "\(parentRoute)\(parentSlug)/\(item.slug)/")
        ]
        if let status = item.frontMatter["status"] as? String {
            ctx["status"] = escapeHTML(status)
        }
        return ctx
    }

    /// Builds the standalone detail plans for a child collection's items, routed
    /// under their parent (`<parentRoute>/<parentSlug>/<slug>/`) with a link
    /// back to the project and prev/next sibling updates within that project.
    private func makeChildCollectionPlans(
        _ resolved: ResolvedChildCollection,
        rendered: [String: String],
        site: [String: Any],
        urlBuilder: SiteURLBuilder,
        lang: String,
        defaultLanguage: String,
        baseURL: String
    ) -> [PagePlan] {
        let parentRoute = normalizedCollectionRoute(resolved.parentConfig.route)
        let detailTemplate = resolved.childConfig.detailTemplate ?? "layouts/post"
        let langPrefix = (lang == defaultLanguage) ? "" : "/\(lang)"
        var plans: [PagePlan] = []
        for (parentSlug, items) in resolved.itemsByParentSlug {
            let projectLink = urlBuilder.link(for: "\(parentRoute)\(parentSlug)/")
            let projectTitle = resolved.parentTitles[parentSlug] ?? parentSlug
            for (index, item) in items.enumerated() {
                let detailRoute = "\(parentRoute)\(parentSlug)/\(item.slug)/"
                var pageContext = collectionDetailPageContext(
                    item: item,
                    site: site,
                    urlBuilder: urlBuilder,
                    detailRoute: detailRoute,
                    taxonomies: [],
                    collectionRoute: parentRoute,
                    rendered: rendered,
                    lang: lang,
                    defaultLanguage: defaultLanguage,
                    baseURL: baseURL
                )
                pageContext["project"] = ["title": escapeHTML(projectTitle), "link": projectLink]
                pageContext["relativeDate"] = escapeHTML(relativeDate(item.date ?? ""))
                if let status = item.frontMatter["status"] as? String {
                    pageContext["status"] = escapeHTML(status)
                }
                // Items are newest-first: the newer sibling is the previous index.
                if index > 0 {
                    pageContext["siblingNewer"] = siblingUpdateRef(
                        items[index - 1], parentRoute: parentRoute, parentSlug: parentSlug, urlBuilder: urlBuilder
                    )
                }
                if index < items.count - 1 {
                    pageContext["siblingOlder"] = siblingUpdateRef(
                        items[index + 1], parentRoute: parentRoute, parentSlug: parentSlug, urlBuilder: urlBuilder
                    )
                }
                let context: [String: Any] = [
                    "site": site,
                    "page": pageContext,
                    "links": ["home": urlBuilder.link(for: "/")],
                    "collection": ["id": resolved.childConfig.id, "route": projectLink]
                ]
                plans.append(PagePlan(route: langPrefix + detailRoute, template: detailTemplate, context: context))
            }
        }
        return plans
    }

    /// A compact {title, link, displayDate} reference to a sibling update.
    private func siblingUpdateRef(
        _ item: CollectionItem,
        parentRoute: String,
        parentSlug: String,
        urlBuilder: SiteURLBuilder
    ) -> [String: Any] {
        [
            "title": escapeHTML(item.title),
            "link": urlBuilder.link(for: "\(parentRoute)\(parentSlug)/\(item.slug)/"),
            "displayDate": escapeHTML(formatDisplayDate(item.date ?? ""))
        ]
    }

    /// Cards for the home "what I'm building" section: the most recent updates
    /// across all projects, each linking to its nested page and naming its
    /// parent project. Falls back to plain collection cards if the configured
    /// collection isn't a child collection.
    private func homeBuildingCards(
        collectionId: String?,
        count: Int,
        childCollections: [String: ResolvedChildCollection],
        collections: [String: Collection],
        lang: String,
        defaultLanguage: String,
        urlBuilder: SiteURLBuilder,
        site: [String: Any]
    ) -> [[String: Any]] {
        guard let collectionId else { return [] }
        guard let resolved = childCollections[collectionId] else {
            return homeCollectionCards(
                collectionId: collectionId,
                count: count,
                collections: collections,
                lang: lang,
                defaultLanguage: defaultLanguage,
                urlBuilder: urlBuilder,
                site: site
            )
        }
        let parentRoute = normalizedCollectionRoute(resolved.parentConfig.route)
        let field = resolved.childConfig.resolvedParentField
        return resolved.recentItems.prefix(count).map { item -> [String: Any] in
            let parentSlug = (item.frontMatter[field] as? String) ?? ""
            var ctx = updateRowContext(item, parentRoute: parentRoute, parentSlug: parentSlug, urlBuilder: urlBuilder)
            ctx["project"] = [
                "title": escapeHTML(resolved.parentTitles[parentSlug] ?? parentSlug),
                "link": urlBuilder.link(for: "\(parentRoute)\(parentSlug)/")
            ]
            return ctx
        }
    }

    /// Build-time relative recency ("today", "3d ago", "2w ago", "5mo ago").
    /// Recomputed on every build; acceptable for a frequently-deployed static
    /// site. Falls back to the formatted date when parsing fails.
    func relativeDate(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "" }
        let parsed: Date? = {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: trimmed) { return date }
            let dayFormatter = DateFormatter()
            dayFormatter.locale = Locale(identifier: "en_US_POSIX")
            dayFormatter.timeZone = TimeZone(identifier: "UTC")
            dayFormatter.dateFormat = "yyyy-MM-dd"
            return dayFormatter.date(from: String(trimmed.prefix(10)))
        }()
        guard let date = parsed else { return formatDisplayDate(raw) }
        let seconds = Date().timeIntervalSince(date)
        let days = Int(seconds / 86_400)
        if days <= 0 { return "today" }
        if days == 1 { return "yesterday" }
        if days < 7 { return "\(days)d ago" }
        if days < 30 { return "\(days / 7)w ago" }
        if days < 365 { return "\(days / 30)mo ago" }
        return "\(days / 365)y ago"
    }

    /// Ensures a collection route ends with a trailing slash so concatenating
    /// `<slug>/` produces a clean detail route.
    func normalizedCollectionRoute(_ raw: String) -> String {
        var route = raw
        if route.hasPrefix("/") == false {
            route = "/" + route
        }
        if route.hasSuffix("/") == false {
            route += "/"
        }
        return route
    }

    func taxonomySlug(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
// swiftlint:enable function_parameter_count

extension PageContextBuilder {
    /// Resolves the effective Umami block for the current build mode.
    /// `.build` uses the top-level fields; `.serve` swaps in the `local`
    /// override block if present and returns nil otherwise — so dev builds
    /// never accidentally ping the production Umami instance. Values are
    /// pre-escaped because they land directly inside HTML attributes
    /// (`data-website-id`, `data-host-url`, etc.).
    func analyticsContext(for siteConfig: SiteConfig, mode: BuildMode) -> [String: Any]? {
        guard let umami = siteConfig.analytics?.umami else { return nil }

        let scriptUrl: String
        let websiteId: String
        let hostUrl: String?
        let domains: String?
        let respectDoNotTrack: Bool?
        let tag: String?
        let events: UmamiEventsConfig?

        switch mode {
        case .build:
            scriptUrl = umami.scriptUrl
            websiteId = umami.websiteId
            hostUrl = umami.hostUrl
            domains = umami.domains
            respectDoNotTrack = umami.respectDoNotTrack
            tag = umami.tag
            events = umami.events
        case .serve:
            guard let local = umami.local else { return nil }
            scriptUrl = local.scriptUrl
            websiteId = local.websiteId
            hostUrl = local.hostUrl
            domains = local.domains
            respectDoNotTrack = local.respectDoNotTrack
            tag = local.tag
            events = local.events
        }

        var umamiCtx: [String: Any] = [
            "scriptUrl": escapeHTML(scriptUrl),
            "websiteId": escapeHTML(websiteId)
        ]
        if let hostUrl { umamiCtx["hostUrl"] = escapeHTML(hostUrl) }
        if let domains { umamiCtx["domains"] = escapeHTML(domains) }
        if let respectDoNotTrack, respectDoNotTrack { umamiCtx["respectDoNotTrack"] = true }
        if let tag { umamiCtx["tag"] = escapeHTML(tag) }
        if let eventsCtx = eventsContext(for: events) { umamiCtx["events"] = eventsCtx }
        return ["umami": umamiCtx]
    }

    /// File extensions treated as downloads by the auto-tracker when a site
    /// turns on `events.downloads` without supplying its own list.
    static let defaultDownloadExtensions = [
        "pdf", "zip", "dmg", "csv", "xlsx", "doc", "docx",
        "pptx", "mp3", "mp4", "png", "jpg", "svg"
    ]

    /// Builds the `events` sub-context for the template. Returns nil unless at
    /// least one tracking flag is on, so the bundled themes emit no event
    /// wiring for the default page-views-only setup. The extension list always
    /// resolves to the config override or the built-in default so the inline
    /// auto-tracker can render a JS array unconditionally.
    func eventsContext(for events: UmamiEventsConfig?) -> [String: Any]? {
        guard let events else { return nil }
        let outboundLinks = events.outboundLinks ?? false
        let downloads = events.downloads ?? false
        let themeElements = events.themeElements ?? false
        guard outboundLinks || downloads || themeElements else { return nil }

        let extensions = (events.downloadExtensions ?? Self.defaultDownloadExtensions)
            .map { escapeHTML($0) }
        var eventsCtx: [String: Any] = ["downloadExtensions": extensions]
        if outboundLinks { eventsCtx["outboundLinks"] = true }
        if downloads { eventsCtx["downloads"] = true }
        if themeElements { eventsCtx["themeElements"] = true }
        return eventsCtx
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var index = 0
        var result: [[Element]] = []
        while index < count {
            let end = Swift.min(index + size, count)
            result.append(Array(self[index..<end]))
            index = end
        }
        return result
    }
}
