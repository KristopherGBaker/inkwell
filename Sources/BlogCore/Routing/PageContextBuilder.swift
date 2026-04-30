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

        let siteContext: [String: Any] = [
            "title": escapeHTML(normalizedSiteTitle),
            "description": escapeHTML(siteDescription),
            "tagline": escapeHTML(siteTagline),
            "searchEnabled": searchEnabled,
            "baseURL": siteConfig.baseURL
        ]

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
        return [
            "slug": post.slug,
            "title": escapeHTML(post.title),
            "summary": escapeHTML(post.summary),
            "date": escapeHTML(post.date),
            "link": urlBuilder.link(for: "/posts/\(post.slug)/"),
            "chips": makeTaxonomyChips(tags: post.tags, categories: post.categories, urlBuilder: urlBuilder)
        ]
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
        let homeContext: [String: Any] = [
            "featured": featured,
            "recent": recent
        ]
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

        let listPageContext: [String: Any] = [
            "type": "collection-list",
            "title": escapeHTML(collection.config.id.capitalized),
            "description": escapeHTML("\(collection.config.id.capitalized) listing"),
            "canonicalURL": escapeHTML(urlBuilder.compose(route: route)),
            "twitterCard": "summary"
        ]
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

        for item in collection.items {
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
                "date": escapeHTML(item.date ?? ""),
                "canonicalURL": escapeHTML(item.normalizedCanonicalURL ?? urlBuilder.compose(route: detailRoute)),
                "twitterCard": (trimmedCoverImage?.isEmpty == false) ? "summary_large_image" : "summary",
                "chips": chips,
                "content": rendered[item.slug] ?? "",
                "frontMatter": item.frontMatter
            ]
            if let trimmed = trimmedCoverImage, trimmed.isEmpty == false {
                let resolved = trimmed.hasPrefix("/") ? urlBuilder.link(for: trimmed) : trimmed
                pageContext["coverImage"] = [
                    "src": escapeHTML(resolved),
                    "alt": escapeHTML(item.title)
                ]
            }

            let context: [String: Any] = [
                "site": site,
                "page": pageContext,
                "links": ["home": urlBuilder.link(for: "/")],
                "collection": [
                    "id": collection.config.id,
                    "route": urlBuilder.link(for: route)
                ]
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
        return [
            "slug": item.slug,
            "title": escapeHTML(item.title),
            "summary": escapeHTML(item.summary ?? ""),
            "date": escapeHTML(item.date ?? ""),
            "link": urlBuilder.link(for: detailRoute),
            "chips": [], // chips are typed-only here; keep callers using card partial happy
            "frontMatter": item.frontMatter
        ]
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
            for value in values.prefix(3) {
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
