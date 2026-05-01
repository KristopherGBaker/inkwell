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
}

public struct PageContextBuilder {
    private let postsPerPage = 6

    public init() {}

    public func buildPlans(
        posts: [PostDocument],
        renderedContent: [String: String],
        baseURL: String = "/",
        siteConfig: SiteConfig = SiteConfig(title: "Field Notes"),
        data: [String: Any] = [:],
        collections: [String: Collection] = [:],
        collectionRenderedContent: [String: [String: String]] = [:],
        pages: [Page] = [],
        pageRenderedContent: [String: String] = [:]
    ) -> [PagePlan] {
        let urlBuilder = SiteURLBuilder(baseURL: baseURL)

        let normalizedSiteTitle = siteConfig.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Field Notes"
            : siteConfig.title
        let siteDescription = siteConfig.description ?? normalizedSiteTitle
        let siteTagline = siteConfig.tagline ?? siteDescription
        let searchEnabled = siteConfig.searchEnabled ?? true

        var siteContext: [String: Any] = [
            "title": escapeHTML(normalizedSiteTitle),
            "description": escapeHTML(siteDescription),
            "tagline": escapeHTML(siteTagline),
            "searchEnabled": searchEnabled,
            "baseURL": siteConfig.baseURL,
            "brandInitial": brandInitial(for: siteConfig),
            "copyrightLine": copyrightLine(for: siteConfig),
            "heroHeadline": heroHeadline(for: siteConfig),
            "footerCta": footerCtaContext(for: siteConfig),
            "themeCopy": themeCopyContext(for: siteConfig)
        ]
        if let brandSubtitle = siteConfig.author?.tagline {
            siteContext["brandSubtitle"] = escapeHTML(brandSubtitle)
        }
        if let author = siteConfig.author {
            siteContext["author"] = authorContext(author, urlBuilder: urlBuilder)
        }
        if let nav = siteConfig.nav, nav.isEmpty == false {
            siteContext["nav"] = nav.map { item -> [String: String] in
                [
                    "label": escapeHTML(item.label),
                    "route": urlBuilder.link(for: item.route)
                ]
            }
        }

        var plans: [PagePlan] = []

        if let configs = siteConfig.collections, configs.isEmpty == false {
            for config in configs {
                guard let collection = collections[config.id] else { continue }
                let rendered = collectionRenderedContent[config.id] ?? [:]
                plans.append(contentsOf: makeCollectionPlans(
                    collection: collection,
                    rendered: rendered,
                    site: siteContext,
                    urlBuilder: urlBuilder
                ))
            }
            for page in pages {
                plans.append(makeStandalonePagePlan(
                    page: page,
                    rendered: pageRenderedContent[page.route] ?? "",
                    site: siteContext,
                    urlBuilder: urlBuilder
                ))
            }
            if let home = siteConfig.home {
                plans = plans.filter { $0.route != "/" }
                plans.append(makeHomePlan(
                    home: home,
                    site: siteContext,
                    collections: collections,
                    urlBuilder: urlBuilder
                ))
            }
            if data.isEmpty == false {
                plans = plans.map { plan in
                    var context = plan.context
                    context["data"] = data
                    return PagePlan(route: plan.route, template: plan.template, context: context)
                }
            }
            return plans
        }

        let mapped = posts.compactMap(mapPost).sorted { $0.date > $1.date }

        let chunks = mapped.chunked(into: postsPerPage)
        let totalPages = max(chunks.count, 1)

        if chunks.isEmpty {
            plans.append(makeLandingPlan(
                route: "/",
                posts: [],
                page: 1,
                totalPages: 1,
                site: siteContext,
                siteTitle: normalizedSiteTitle,
                siteDescription: siteDescription,
                urlBuilder: urlBuilder
            ))
        } else {
            for (index, chunk) in chunks.enumerated() {
                let pageNumber = index + 1
                let route = pageNumber == 1 ? "/" : "/page/\(pageNumber)/"
                plans.append(makeLandingPlan(
                    route: route,
                    posts: chunk,
                    page: pageNumber,
                    totalPages: totalPages,
                    site: siteContext,
                    siteTitle: normalizedSiteTitle,
                    siteDescription: siteDescription,
                    urlBuilder: urlBuilder
                ))
            }
        }

        plans.append(makeArchivePlan(
            posts: mapped,
            site: siteContext,
            urlBuilder: urlBuilder
        ))

        for post in mapped {
            let content = renderedContent[post.slug] ?? ""
            plans.append(makePostPlan(
                post: post,
                content: content,
                site: siteContext,
                urlBuilder: urlBuilder
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

        if let home = siteConfig.home {
            plans = plans.filter { $0.route != "/" }
            plans.append(makeHomePlan(
                home: home,
                site: siteContext,
                collections: collections,
                urlBuilder: urlBuilder
            ))
        }

        if data.isEmpty == false {
            plans = plans.map { plan in
                var context = plan.context
                context["data"] = data
                return PagePlan(route: plan.route, template: plan.template, context: context)
            }
        }

        return plans
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
            coverImage: post.frontMatter.coverImage
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
        urlBuilder: SiteURLBuilder
    ) -> PagePlan {
        let route = "/posts/\(post.slug)/"
        let chips = makeTaxonomyChips(tags: post.tags, categories: post.categories, urlBuilder: urlBuilder)
        let trimmedCoverImage = post.coverImage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let coverImageContext: [String: String]?
        if let trimmed = trimmedCoverImage, trimmed.isEmpty == false {
            let resolved = trimmed.hasPrefix("/") ? urlBuilder.link(for: trimmed) : trimmed
            coverImageContext = [
                "src": escapeHTML(resolved),
                "alt": escapeHTML(post.title)
            ]
        } else {
            coverImageContext = nil
        }
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
            "content": content
        ]
        if let coverImageContext {
            pageContext["coverImage"] = coverImageContext
        }

        let context: [String: Any] = [
            "site": site,
            "page": pageContext,
            "links": ["home": urlBuilder.link(for: "/")]
        ]
        return PagePlan(route: route, template: "layouts/post", context: context)
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
        urlBuilder: SiteURLBuilder
    ) -> PagePlan {
        let route = "/"
        let title = (site["title"] as? String) ?? "Home"
        let description = (site["description"] as? String) ?? title

        let featured: [[String: Any]] = home.featuredCollection
            .flatMap { collections[$0] }
            .map { collection in
                let count = home.featuredCount ?? 4
                return Array(collection.items.prefix(count)).map {
                    collectionItemCardContext($0, route: normalizedCollectionRoute(collection.config.route), urlBuilder: urlBuilder)
                }
            } ?? []
        let recent: [[String: Any]] = home.recentCollection
            .flatMap { collections[$0] }
            .map { collection in
                let count = home.recentCount ?? 3
                return Array(collection.items.prefix(count)).map {
                    collectionItemCardContext($0, route: normalizedCollectionRoute(collection.config.route), urlBuilder: urlBuilder)
                }
            } ?? []

        let pageContext: [String: Any] = [
            "type": "home",
            "title": title,
            "description": description,
            "canonicalURL": escapeHTML(urlBuilder.compose(route: route)),
            "twitterCard": "summary"
        ]
        var homeContext: [String: Any] = [
            "featured": featured,
            "recent": recent
        ]
        if let cta = home.heroPrimaryCta {
            homeContext["heroPrimaryCta"] = ctaContext(cta)
        }
        if let cta = home.heroSecondaryCta {
            homeContext["heroSecondaryCta"] = ctaContext(cta)
        }
        homeContext["featuredLabel"] = escapeHTML(home.featuredLabel ?? "Selected work")
        homeContext["recentLabel"] = escapeHTML(home.recentLabel ?? "Recent writing")
        homeContext["aboutEyebrow"] = escapeHTML(home.aboutEyebrow ?? "About")
        if let cta = home.featuredCta {
            homeContext["featuredCta"] = ctaContext(cta)
        }
        if let cta = home.recentCta {
            homeContext["recentCta"] = ctaContext(cta)
        }
        if let links = home.aboutLinks, links.isEmpty == false {
            homeContext["aboutLinks"] = links.map { ctaContext($0) }
        }
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
        return PagePlan(route: route, template: "layouts/\(home.template)", context: context)
    }

    /// Hero headline with `*word*` → `<em class="accent-em">word</em>` transform.
    /// Falls back to the site title (escaped) when no headline is configured.
    func heroHeadline(for siteConfig: SiteConfig) -> String {
        let raw = siteConfig.heroHeadline ?? siteConfig.title
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
    /// `siteConfig.footerCta` is unset or only partially specified.
    func footerCtaContext(for siteConfig: SiteConfig) -> [String: String] {
        let eyebrow = siteConfig.footerCta?.eyebrow ?? "Get in touch"
        let headline = siteConfig.footerCta?.headline ?? "Quietly open to good work."
        return [
            "eyebrow": escapeHTML(eyebrow),
            "headline": escapeHTML(headline)
        ]
    }

    /// Theme-level chrome strings — escaped, with the quiet-theme English
    /// defaults filled in for any field the site config omits.
    func themeCopyContext(for siteConfig: SiteConfig) -> [String: String] {
        let copy = siteConfig.themeCopy
        return [
            "workCardCta": escapeHTML(copy?.workCardCta ?? "Read case study"),
            "caseStudyBack": escapeHTML(copy?.caseStudyBack ?? "← All work"),
            "caseStudyNextLabel": escapeHTML(copy?.caseStudyNextLabel ?? "Next"),
            "caseStudyNextFallbackCta": escapeHTML(copy?.caseStudyNextFallbackCta ?? "Read case study"),
            "aboutEyebrow": escapeHTML(copy?.aboutEyebrow ?? "04 · About"),
            "aboutResumeCta": escapeHTML(copy?.aboutResumeCta ?? "Read the résumé"),
            "aboutEmailCta": escapeHTML(copy?.aboutEmailCta ?? "Email me"),
            "notFoundEyebrow": escapeHTML(copy?.notFoundEyebrow ?? "404 · NOT FOUND"),
            "notFoundHeadline": escapeHTML(copy?.notFoundHeadline ?? "This page is in another castle."),
            "notFoundBody": escapeHTML(copy?.notFoundBody ?? "Or it never existed. Or it's still drafted in a markdown file on my laptop. Try the home page."),
            "notFoundCta": escapeHTML(copy?.notFoundCta ?? "Back home"),
            "themeToggleLabel": escapeHTML(copy?.themeToggleLabel ?? "Toggle theme")
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

    func authorContext(_ author: AuthorConfig, urlBuilder: SiteURLBuilder) -> [String: Any] {
        var context: [String: Any] = [
            "name": escapeHTML(author.name)
        ]
        if let role = author.role { context["role"] = escapeHTML(role) }
        if let location = author.location { context["location"] = escapeHTML(location) }
        if let email = author.email { context["email"] = escapeHTML(email) }
        if let tagline = author.tagline { context["tagline"] = escapeHTML(tagline) }
        if let timezone = author.timezone { context["timezone"] = escapeHTML(timezone) }
        if let heroSummary = author.heroSummary { context["heroSummary"] = escapeHTML(heroSummary) }
        if let aboutTeaser = author.aboutTeaser { context["aboutTeaser"] = escapeHTML(aboutTeaser) }
        if let portrait = author.portrait?.trimmingCharacters(in: .whitespacesAndNewlines), portrait.isEmpty == false {
            context["portrait"] = escapeHTML(portrait.hasPrefix("/") ? urlBuilder.link(for: portrait) : portrait)
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

    func makeStandalonePagePlan(
        page: Page,
        rendered: String,
        site: [String: Any],
        urlBuilder: SiteURLBuilder
    ) -> PagePlan {
        let title = page.title ?? humanize(routeAsTitle: page.route)
        let description = page.summary ?? title
        let pageContext: [String: Any] = [
            "type": "page",
            "title": escapeHTML(title),
            "description": escapeHTML(description),
            "canonicalURL": escapeHTML(urlBuilder.compose(route: page.route)),
            "twitterCard": "summary",
            "layout": page.layout,
            "content": rendered,
            "frontMatter": page.frontMatter
        ]
        let context: [String: Any] = [
            "site": site,
            "page": pageContext,
            "links": ["home": urlBuilder.link(for: "/")]
        ]
        return PagePlan(route: page.route, template: "layouts/\(page.layout)", context: context)
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
        site: [String: Any],
        urlBuilder: SiteURLBuilder
    ) -> [PagePlan] {
        let route = normalizedCollectionRoute(collection.config.route)
        let listTemplate = collection.config.listTemplate ?? "layouts/post-list"
        let detailTemplate = collection.config.detailTemplate ?? "layouts/post"

        var plans: [PagePlan] = []

        let itemContexts = collection.items.map {
            collectionItemCardContext($0, route: route, urlBuilder: urlBuilder)
        }

        let listTitle = collection.config.headline ?? collection.config.id.capitalized
        var listPageContext: [String: Any] = [
            "type": "collection-list",
            "title": escapeHTML(listTitle),
            "headline": renderAccentItalics(listTitle),
            "description": escapeHTML(collection.config.lede ?? "\(collection.config.id.capitalized) listing"),
            "canonicalURL": escapeHTML(urlBuilder.compose(route: route)),
            "twitterCard": "summary"
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
        plans.append(PagePlan(route: route, template: listTemplate, context: listContext))

        for (index, item) in collection.items.enumerated() {
            let detailRoute = "\(route)\(item.slug)/"
            let chips = makeCollectionTaxonomyChips(
                item: item,
                taxonomies: collection.config.resolvedTaxonomies,
                collectionRoute: route,
                urlBuilder: urlBuilder
            )
            let trimmedCoverImage = item.coverImage?.trimmingCharacters(in: .whitespacesAndNewlines)
            var pageContext: [String: Any] = [
                "type": "collection-detail",
                "title": escapeHTML(item.title),
                "description": escapeHTML(item.summary ?? item.title),
                "summary": escapeHTML(item.summary ?? ""),
                "date": escapeHTML(item.date ?? ""),
                "displayDate": escapeHTML(formatDisplayDate(item.date ?? "")),
                "readMin": estimatedReadingTime(forBody: item.body),
                "canonicalURL": escapeHTML(item.normalizedCanonicalURL ?? urlBuilder.compose(route: detailRoute)),
                "twitterCard": (trimmedCoverImage?.isEmpty == false) ? "summary_large_image" : "summary",
                "chips": chips,
                "content": rendered[item.slug] ?? "",
                "frontMatter": item.frontMatter
            ]
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
            if let trimmed = trimmedCoverImage, trimmed.isEmpty == false {
                let resolved = trimmed.hasPrefix("/") ? urlBuilder.link(for: trimmed) : trimmed
                pageContext["coverImage"] = [
                    "src": escapeHTML(resolved),
                    "alt": escapeHTML(item.title)
                ]
            }

            // Wrap-around "next" sibling — used by the case-study layout's
            // bottom navigation. Skipped when the collection has only one item.
            var collectionContext: [String: Any] = [
                "id": collection.config.id,
                "route": urlBuilder.link(for: route)
            ]
            if collection.items.count > 1 {
                let nextItem = collection.items[(index + 1) % collection.items.count]
                let nextDetailRoute = "\(route)\(nextItem.slug)/"
                var next: [String: Any] = [
                    "title": escapeHTML(nextItem.title),
                    "link": urlBuilder.link(for: nextDetailRoute)
                ]
                if let nextOrg = nextItem.frontMatter["org"] as? String {
                    next["org"] = escapeHTML(nextOrg)
                }
                if let nextYear = nextItem.frontMatter["year"] {
                    next["year"] = String(describing: nextYear)
                }
                collectionContext["next"] = next
            }

            let context: [String: Any] = [
                "site": site,
                "page": pageContext,
                "links": ["home": urlBuilder.link(for: "/")],
                "collection": collectionContext
            ]
            plans.append(PagePlan(route: detailRoute, template: detailTemplate, context: context))
        }

        for taxonomy in collection.config.resolvedTaxonomies {
            let extractor: (CollectionItem) -> [String]
            switch taxonomy {
            case "tags":
                extractor = { $0.tags ?? [] }
            case "categories":
                extractor = { $0.categories ?? [] }
            default:
                extractor = { item in
                    if let array = item.frontMatter[taxonomy] as? [String] { return array }
                    if let array = item.frontMatter[taxonomy] as? [Any] { return array.compactMap { $0 as? String } }
                    return []
                }
            }

            var grouped: [String: [CollectionItem]] = [:]
            for item in collection.items {
                for value in extractor(item) {
                    grouped[value, default: []].append(item)
                }
            }

            for key in grouped.keys.sorted() {
                let slug = taxonomySlug(key)
                let taxRoute = "\(route)\(taxonomy)/\(slug)/"
                let title = "\(taxonomy.capitalized): \(key)"
                let description = "Archive page for \(taxonomy) \(key)."
                let cards = (grouped[key] ?? []).map {
                    collectionItemCardContext($0, route: route, urlBuilder: urlBuilder)
                }
                let pageContext: [String: Any] = [
                    "type": "collection-taxonomy",
                    "kind": taxonomy,
                    "label": escapeHTML(key),
                    "title": escapeHTML(title),
                    "description": escapeHTML(description),
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
                plans.append(PagePlan(route: taxRoute, template: "layouts/taxonomy", context: taxContext))
            }
        }

        return plans
    }

    func collectionItemCardContext(_ item: CollectionItem, route: String, urlBuilder: SiteURLBuilder) -> [String: Any] {
        let detailRoute = "\(route)\(item.slug)/"
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
            "readMin": estimatedReadingTime(forBody: item.body)
        ]
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
        return ctx
    }

    /// Resolve the card's cover image: prefer explicit `coverImage`, otherwise fall back
    /// to the first `shots` entry. Always returns a renderable URL string.
    private func resolvedCoverImage(for item: CollectionItem, urlBuilder: SiteURLBuilder) -> String? {
        if let cover = item.coverImage?.trimmingCharacters(in: .whitespacesAndNewlines), cover.isEmpty == false {
            return escapeHTML(cover.hasPrefix("/") ? urlBuilder.link(for: cover) : cover)
        }
        if let shots = item.frontMatter["shots"] as? [Any], let first = shots.first as? String {
            let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                return escapeHTML(trimmed.hasPrefix("/") ? urlBuilder.link(for: trimmed) : trimmed)
            }
        }
        return nil
    }

    /// Coarse word-count-based reading-time estimate (200 wpm).
    /// Returns at least 1 for non-empty bodies.
    private func estimatedReadingTime(forBody body: String) -> Int {
        let words = body.split { $0.isWhitespace || $0.isNewline }.count
        guard words > 0 else { return 0 }
        return max(1, Int((Double(words) / 200.0).rounded()))
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
