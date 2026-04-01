import Foundation

public struct BuiltPage: Equatable {
    public let route: String
    public let html: String

    public init(route: String, html: String) {
        self.route = route
        self.html = html
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

private struct PageMetadata {
    let title: String
    let description: String
    let canonicalURL: String
    let twitterCard: String
}

private struct IndexPageContext {
    let route: String
    let cards: String
    let currentPage: Int
    let totalPages: Int
    let siteTitle: String
    let siteDescription: String
    let siteTagline: String
    let searchEnabled: Bool
}

public struct RouteBuilder {
    private let postsPerPage = 6

    public init() {}

    public func buildPages(posts: [PostDocument], renderedContent: [String: String], baseURL: String = "/", siteConfig: SiteConfig = SiteConfig(title: "Field Notes")) -> [BuiltPage] {
        let mapped = posts.compactMap(mapPost).sorted { $0.date > $1.date }
        let urlBuilder = SiteURLBuilder(baseURL: baseURL)
        var pages: [BuiltPage] = []

        let chunks = mapped.chunked(into: postsPerPage)
        let totalPages = max(chunks.count, 1)
        let normalizedSiteTitle = siteConfig.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Field Notes" : siteConfig.title
        let siteDescription = siteConfig.description ?? normalizedSiteTitle
        let siteTagline = siteConfig.tagline ?? siteDescription
        let searchEnabled = siteConfig.searchEnabled ?? true

        if chunks.isEmpty {
            let context = IndexPageContext(route: "/", cards: "", currentPage: 1, totalPages: 1, siteTitle: normalizedSiteTitle, siteDescription: siteDescription, siteTagline: siteTagline, searchEnabled: searchEnabled)
            pages.append(BuiltPage(route: "/", html: renderIndex(context, urlBuilder: urlBuilder)))
        } else {
            for (index, chunk) in chunks.enumerated() {
                let page = index + 1
                let route = page == 1 ? "/" : "/page/\(page)/"
                let cards = chunk.map { renderCard($0, urlBuilder: urlBuilder) }.joined(separator: "")
                let context = IndexPageContext(
                    route: route,
                    cards: cards,
                    currentPage: page,
                    totalPages: totalPages,
                    siteTitle: normalizedSiteTitle,
                    siteDescription: siteDescription,
                    siteTagline: siteTagline,
                    searchEnabled: searchEnabled
                )
                pages.append(BuiltPage(route: route, html: renderIndex(context, urlBuilder: urlBuilder)))
            }
        }

        let archiveCards = mapped.map { renderCard($0, urlBuilder: urlBuilder) }.joined(separator: "")
        pages.append(BuiltPage(route: "/archive/", html: renderArchive(route: "/archive/", cards: archiveCards, urlBuilder: urlBuilder)))

        for post in mapped {
            let content = renderedContent[post.slug] ?? ""
            let route = "/posts/\(post.slug)/"
            pages.append(BuiltPage(route: route, html: renderPost(route: route, post: post, content: content, urlBuilder: urlBuilder)))
        }

        pages.append(contentsOf: buildTaxonomyPages(kind: "tags", posts: mapped, urlBuilder: urlBuilder, extractor: { $0.tags }))
        pages.append(contentsOf: buildTaxonomyPages(kind: "categories", posts: mapped, urlBuilder: urlBuilder, extractor: { $0.categories }))

        return pages
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

private extension RouteBuilder {
    func renderIndex(_ context: IndexPageContext, urlBuilder: SiteURLBuilder) -> String {
        let pagination = renderPagination(currentPage: context.currentPage, totalPages: context.totalPages, urlBuilder: urlBuilder)
        let archiveLink = urlBuilder.link(for: "/archive/")
        let searchBlock = context.searchEnabled ? """
                <div class="mt-7">
                  <label for="search-input" class="text-xs uppercase tracking-[0.18em] text-stone-500 dark:text-stone-400">Search entries</label>
                  <input id="search-input" type="search" autocomplete="off" placeholder="Type 2+ characters to search titles, summaries, and content..." class="mt-2 w-full rounded-xl border border-stone-300/80 bg-white/80 px-4 py-3 text-sm text-stone-800 shadow-sm outline-none transition placeholder:text-stone-500 focus:border-amber-700/60 focus:ring-2 focus:ring-amber-700/20 dark:border-stone-700 dark:bg-stone-900/80 dark:text-stone-100 dark:placeholder:text-stone-400 dark:focus:border-amber-300 dark:focus:ring-amber-300/20">
                  <p id="search-status" class="mt-2 text-xs text-stone-500 dark:text-stone-400"></p>
                  <div id="search-results" class="mt-4 hidden grid gap-3" aria-live="polite"></div>
                </div>
        """ : ""
        let metadata = PageMetadata(
            title: context.siteTitle,
            description: context.siteDescription,
            canonicalURL: urlBuilder.compose(route: context.route),
            twitterCard: "summary"
        )
        return """
        <html>
          <head>
            <meta charset="utf-8">
            <title>\(escapeHTML(context.siteTitle))</title>
            <meta name="description" content="\(escapeAttribute(context.siteDescription))">
            \(renderMetadata(metadata))
          </head>
          <body class="antialiased text-stone-800 dark:bg-stone-950 dark:text-stone-100">
            <div class="pointer-events-none fixed inset-0 -z-10 bg-[radial-gradient(circle_at_20%_10%,rgba(245,158,11,0.13),transparent_48%),radial-gradient(circle_at_80%_0%,rgba(28,25,23,0.08),transparent_35%),linear-gradient(to_bottom,#faf7f2,#f4efe7)] dark:bg-[radial-gradient(circle_at_20%_10%,rgba(245,158,11,0.08),transparent_42%),radial-gradient(circle_at_75%_0%,rgba(250,250,249,0.06),transparent_28%),linear-gradient(to_bottom,#111315,#0a0b0d)]"></div>
            <main class="mx-auto max-w-5xl px-6 pb-16 pt-12 md:px-10 md:pt-20">
              <header class="mb-12 border-b border-stone-300/80 pb-8 dark:border-stone-700/80">
                <div class="flex items-center justify-between gap-4">
                  <p class="text-xs uppercase tracking-[0.28em] text-stone-500 dark:text-stone-400">\(escapeHTML(context.siteTitle))</p>
                  <div class="flex items-center gap-3">
                    <a href="\(archiveLink)" class="text-xs font-medium uppercase tracking-[0.14em] text-stone-600 transition hover:text-amber-800 dark:text-stone-300 dark:hover:text-amber-200">Archive</a>
                    <button type="button" onclick="toggleTheme()" class="rounded-full border border-stone-400/70 px-3 py-1 text-xs font-medium uppercase tracking-[0.14em] text-stone-700 transition hover:border-amber-700/60 hover:text-amber-800 dark:border-stone-600 dark:text-stone-200 dark:hover:border-amber-300 dark:hover:text-amber-200">Toggle Theme</button>
                  </div>
                </div>
                <h1 class="mt-4 max-w-3xl font-display text-4xl leading-[1.05] text-stone-900 dark:text-stone-100 md:text-6xl">\(escapeHTML(context.siteTitle))</h1>
                <p class="mt-5 max-w-2xl text-base leading-relaxed text-stone-700 dark:text-stone-300 md:text-lg">\(escapeHTML(context.siteTagline))</p>
                \(searchBlock)
              </header>
              <section class="grid gap-5 md:grid-cols-2">\(context.cards)</section>
              \(pagination)
            </main>
          </body>
        </html>
        """
    }

    func renderArchive(route: String, cards: String, urlBuilder: SiteURLBuilder) -> String {
        let homeLink = urlBuilder.link(for: "/")
        let metadata = PageMetadata(
            title: "Archive",
            description: "Archive of published journal entries.",
            canonicalURL: urlBuilder.compose(route: route),
            twitterCard: "summary"
        )
        return """
        <html>
          <head>
            <meta charset="utf-8">
            <title>Archive</title>
            <meta name="description" content="Archive of published journal entries.">
            \(renderMetadata(metadata))
          </head>
          <body class="antialiased text-stone-800 dark:bg-stone-950 dark:text-stone-100">
            <div class="pointer-events-none fixed inset-0 -z-10 bg-[radial-gradient(circle_at_20%_10%,rgba(245,158,11,0.13),transparent_48%),radial-gradient(circle_at_80%_0%,rgba(28,25,23,0.08),transparent_35%),linear-gradient(to_bottom,#faf7f2,#f4efe7)] dark:bg-[radial-gradient(circle_at_20%_10%,rgba(245,158,11,0.08),transparent_42%),radial-gradient(circle_at_75%_0%,rgba(250,250,249,0.06),transparent_28%),linear-gradient(to_bottom,#111315,#0a0b0d)]"></div>
            <main class="mx-auto max-w-5xl px-6 pb-16 pt-12 md:px-10 md:pt-20">
              <div class="flex items-center justify-between gap-4">
                <a href="\(homeLink)" class="text-sm font-medium text-amber-800 hover:text-amber-900 dark:text-amber-300 dark:hover:text-amber-200">\u{2190} Back to home</a>
                <button type="button" onclick="toggleTheme()" class="rounded-full border border-stone-400/70 px-3 py-1 text-xs font-medium uppercase tracking-[0.14em] text-stone-700 transition hover:border-amber-700/60 hover:text-amber-800 dark:border-stone-600 dark:text-stone-200 dark:hover:border-amber-300 dark:hover:text-amber-200">Toggle Theme</button>
              </div>
              <header class="mt-6 border-b border-stone-300/70 pb-6 dark:border-stone-700/70">
                <p class="text-xs uppercase tracking-[0.22em] text-stone-500 dark:text-stone-400">Published entries</p>
                <h1 class="mt-3 font-display text-4xl leading-tight text-stone-900 dark:text-stone-100 md:text-5xl">Archive</h1>
              </header>
              <section class="mt-8 grid gap-5 md:grid-cols-2">\(cards)</section>
            </main>
          </body>
        </html>
        """
    }

    func renderCard(_ post: RenderablePost, urlBuilder: SiteURLBuilder) -> String {
        let postLink = urlBuilder.link(for: "/posts/\(post.slug)/")
        let chips = renderTaxonomyChips(tags: post.tags, categories: post.categories, urlBuilder: urlBuilder)
        return """
        <article class="group rounded-2xl border border-stone-300/70 bg-stone-50/60 p-6 shadow-[0_10px_40px_-22px_rgba(28,25,23,0.45)] transition hover:-translate-y-0.5 hover:border-amber-700/40 hover:shadow-[0_18px_50px_-24px_rgba(146,64,14,0.35)] dark:border-stone-700 dark:bg-stone-900/55 dark:shadow-[0_16px_42px_-28px_rgba(0,0,0,0.8)]">
          <p class="text-xs uppercase tracking-[0.22em] text-stone-500 dark:text-stone-400">\(post.date)</p>
          <h2 class="mt-2 font-display text-2xl leading-tight text-stone-900 dark:text-stone-50"><a class="decoration-amber-700/40 underline-offset-4 group-hover:underline" href="\(postLink)">\(escapeHTML(post.title))</a></h2>
          <p class="mt-3 text-sm leading-relaxed text-stone-700 dark:text-stone-300">\(escapeHTML(post.summary))</p>
          <div class="mt-4 flex flex-wrap gap-2">\(chips)</div>
          <a class="mt-4 inline-flex items-center gap-2 text-sm font-medium text-amber-800 dark:text-amber-300" href="\(postLink)">Read entry <span aria-hidden="true">-></span></a>
        </article>
        """
    }

    func renderPost(route: String, post: RenderablePost, content: String, urlBuilder: SiteURLBuilder) -> String {
        let homeLink = urlBuilder.link(for: "/")
        let chips = renderTaxonomyChips(tags: post.tags, categories: post.categories, urlBuilder: urlBuilder)
        let trimmedCoverImage = post.coverImage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let coverImageSource = trimmedCoverImage.map { imagePath in
            imagePath.hasPrefix("/") ? urlBuilder.link(for: imagePath) : imagePath
        }
        let coverImage = (trimmedCoverImage?.isEmpty == false)
            ? "<figure class=\"mt-8 overflow-hidden rounded-2xl border border-stone-300/70 shadow-[0_14px_48px_-28px_rgba(28,25,23,0.6)] dark:border-stone-700\"><img src=\"\(escapeAttribute(coverImageSource!))\" alt=\"Cover image for \(escapeAttribute(post.title))\" class=\"h-auto w-full object-cover\"></figure>"
            : ""
        let metadata = PageMetadata(
            title: post.title,
            description: post.summary,
            canonicalURL: post.canonicalURL ?? urlBuilder.compose(route: route),
            twitterCard: coverImage.isEmpty ? "summary" : "summary_large_image"
        )

        return """
        <html>
          <head>
            <meta charset="utf-8">
            <title>\(escapeHTML(post.title))</title>
            <meta name="description" content="\(escapeAttribute(post.summary))">
            \(renderMetadata(metadata))
          </head>
          <body class="antialiased text-stone-800 dark:bg-stone-950 dark:text-stone-100">
            <div class="pointer-events-none fixed inset-0 -z-10 bg-[radial-gradient(circle_at_20%_10%,rgba(245,158,11,0.13),transparent_48%),radial-gradient(circle_at_80%_0%,rgba(28,25,23,0.08),transparent_35%),linear-gradient(to_bottom,#faf7f2,#f4efe7)] dark:bg-[radial-gradient(circle_at_20%_10%,rgba(245,158,11,0.08),transparent_42%),radial-gradient(circle_at_75%_0%,rgba(250,250,249,0.06),transparent_28%),linear-gradient(to_bottom,#111315,#0a0b0d)]"></div>
            <main class="mx-auto max-w-3xl px-6 pb-20 pt-10 md:px-10 md:pt-14">
              <div class="flex items-center justify-between gap-4">
                <a href="\(homeLink)" class="inline-flex items-center gap-2 text-sm font-medium text-amber-800 hover:text-amber-900 dark:text-amber-300 dark:hover:text-amber-200">\u{2190} Back to entries</a>
                <button type="button" onclick="toggleTheme()" class="rounded-full border border-stone-400/70 px-3 py-1 text-xs font-medium uppercase tracking-[0.14em] text-stone-700 transition hover:border-amber-700/60 hover:text-amber-800 dark:border-stone-600 dark:text-stone-200 dark:hover:border-amber-300 dark:hover:text-amber-200">Toggle Theme</button>
              </div>
              <header class="mt-6 border-b border-stone-300/70 pb-6 dark:border-stone-700/70">
                <p class="text-xs uppercase tracking-[0.22em] text-stone-500 dark:text-stone-400">\(post.date)</p>
                <h1 class="mt-3 font-display text-4xl leading-tight text-stone-900 dark:text-stone-100 md:text-5xl">\(escapeHTML(post.title))</h1>
                <div class="mt-4 flex flex-wrap gap-2">\(chips)</div>
              </header>
              \(coverImage)
              <article class="post-content mt-8 text-stone-800 dark:text-stone-200">\(content)</article>
            </main>
          </body>
        </html>
        """
    }

    func buildTaxonomyPages(kind: String, posts: [RenderablePost], urlBuilder: SiteURLBuilder, extractor: (RenderablePost) -> [String]) -> [BuiltPage] {
        var grouped: [String: [RenderablePost]] = [:]
        for post in posts {
            for value in extractor(post) {
                grouped[value, default: []].append(post)
            }
        }

        return grouped.keys.sorted().map { key in
            let slug = taxonomySlug(key)
            let route = "/\(kind)/\(slug)/"
            let cards = (grouped[key] ?? []).map { renderCard($0, urlBuilder: urlBuilder) }.joined(separator: "")
            let title = "\(kind.capitalized): \(key)"
            let metadata = PageMetadata(
                title: title,
                description: "Archive page for \(kind) \(key).",
                canonicalURL: urlBuilder.compose(route: route),
                twitterCard: "summary"
            )
            let html = """
            <html>
              <head>
                <meta charset="utf-8">
                <title>\(escapeHTML(title))</title>
                <meta name="description" content="Archive page for \(kind) \(escapeAttribute(key)).">
                \(renderMetadata(metadata))
              </head>
              <body class="antialiased text-stone-800 dark:bg-stone-950 dark:text-stone-100">
                <main class="mx-auto max-w-5xl px-6 pb-16 pt-12 md:px-10 md:pt-20">
                  <a href="\(urlBuilder.link(for: "/"))" class="text-sm text-amber-800 dark:text-amber-300">\u{2190} Back to home</a>
                  <h1 class="mt-4 font-display text-4xl text-stone-900 dark:text-stone-100">\(escapeHTML(title))</h1>
                  <section class="mt-8 grid gap-5 md:grid-cols-2">\(cards)</section>
                </main>
              </body>
            </html>
            """
            return BuiltPage(route: route, html: html)
        }
    }

    func renderMetadata(_ metadata: PageMetadata) -> String {
        let title = escapeAttribute(metadata.title)
        let description = escapeAttribute(metadata.description)
        let canonicalURL = escapeAttribute(metadata.canonicalURL)

        return """
        <link rel="canonical" href="\(canonicalURL)">
        <meta property="og:title" content="\(title)">
        <meta property="og:description" content="\(description)">
        <meta property="og:url" content="\(canonicalURL)">
        <meta name="twitter:card" content="\(metadata.twitterCard)">
        """
    }

    func renderTaxonomyChips(tags: [String], categories: [String], urlBuilder: SiteURLBuilder) -> String {
        let tagChips = tags.prefix(3).map { value in
            let href = urlBuilder.link(for: "/tags/\(taxonomySlug(value))/")
            return "<a href=\"\(href)\" class=\"rounded-full border border-stone-400/50 px-2.5 py-1 text-[11px] uppercase tracking-[0.12em] text-stone-600 transition hover:border-amber-700/50 hover:text-amber-800 dark:border-stone-600 dark:text-stone-300 dark:hover:border-amber-300 dark:hover:text-amber-200\">\(escapeHTML(value))</a>"
        }
        let categoryChips = categories.prefix(2).map { value in
            let href = urlBuilder.link(for: "/categories/\(taxonomySlug(value))/")
            return "<a href=\"\(href)\" class=\"rounded-full border border-stone-400/50 px-2.5 py-1 text-[11px] uppercase tracking-[0.12em] text-stone-600 transition hover:border-amber-700/50 hover:text-amber-800 dark:border-stone-600 dark:text-stone-300 dark:hover:border-amber-300 dark:hover:text-amber-200\">\(escapeHTML(value))</a>"
        }
        return (tagChips + categoryChips).joined(separator: "")
    }

    func renderPagination(currentPage: Int, totalPages: Int, urlBuilder: SiteURLBuilder) -> String {
        guard totalPages > 1 else { return "" }
        let links = (1...totalPages).map { page -> String in
            let href = urlBuilder.link(for: page == 1 ? "/" : "/page/\(page)/")
            let active = page == currentPage
                ? "border-amber-700 bg-amber-100 text-amber-900 dark:border-amber-300 dark:bg-amber-300/15 dark:text-amber-200"
                : "border-stone-300 text-stone-700 hover:border-amber-600 hover:text-amber-800 dark:border-stone-700 dark:text-stone-300 dark:hover:border-amber-300 dark:hover:text-amber-200"
            return "<a href=\"\(href)\" class=\"rounded-full border px-3 py-1 text-sm \(active)\">\(page)</a>"
        }.joined(separator: "")
        return "<nav class=\"mt-10 flex flex-wrap items-center gap-2\" aria-label=\"Pagination\">\(links)</nav>"
    }

    func taxonomySlug(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    func escapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    func escapeHTML(_ value: String) -> String {
        escapeAttribute(value)
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
