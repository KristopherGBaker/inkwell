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
        siteConfig: SiteConfig = SiteConfig(title: "Field Notes")
    ) -> [PagePlan] {
        let mapped = posts.compactMap(mapPost).sorted { $0.date > $1.date }
        let urlBuilder = SiteURLBuilder(baseURL: baseURL)
        var plans: [PagePlan] = []

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
