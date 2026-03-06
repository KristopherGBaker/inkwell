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
    let coverImage: String?
}

public struct RouteBuilder {
    private let postsPerPage = 6

    public init() {}

    public func buildPages(posts: [PostDocument], renderedContent: [String: String]) -> [BuiltPage] {
        let mapped = posts.compactMap(mapPost).sorted { $0.date > $1.date }
        var pages: [BuiltPage] = []

        let chunks = mapped.chunked(into: postsPerPage)
        let totalPages = max(chunks.count, 1)

        if chunks.isEmpty {
            pages.append(BuiltPage(route: "/", html: renderIndex(cards: "", currentPage: 1, totalPages: 1)))
        } else {
            for (index, chunk) in chunks.enumerated() {
                let page = index + 1
                let route = page == 1 ? "/" : "/page/\(page)/"
                let cards = chunk.map(renderCard).joined(separator: "")
                pages.append(BuiltPage(route: route, html: renderIndex(cards: cards, currentPage: page, totalPages: totalPages)))
            }
        }

        for post in mapped {
            let content = renderedContent[post.slug] ?? ""
            pages.append(BuiltPage(route: "/posts/\(post.slug)/", html: renderPost(post: post, content: content)))
        }

        pages.append(contentsOf: buildTaxonomyPages(kind: "tags", posts: mapped, extractor: { $0.tags }))
        pages.append(contentsOf: buildTaxonomyPages(kind: "categories", posts: mapped, extractor: { $0.categories }))

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
            coverImage: post.frontMatter.coverImage
        )
    }

    private func renderIndex(cards: String, currentPage: Int, totalPages: Int) -> String {
        let pagination = renderPagination(currentPage: currentPage, totalPages: totalPages)
        return """
        <html>
          <head>
            <meta charset="utf-8">
            <title>Field Notes</title>
            <meta name="description" content="Personal journal covering work notes, ideas, and life updates.">
          </head>
          <body class="antialiased text-stone-800 dark:bg-stone-950 dark:text-stone-100">
            <div class="pointer-events-none fixed inset-0 -z-10 bg-[radial-gradient(circle_at_20%_10%,rgba(245,158,11,0.13),transparent_48%),radial-gradient(circle_at_80%_0%,rgba(28,25,23,0.08),transparent_35%),linear-gradient(to_bottom,#faf7f2,#f4efe7)] dark:bg-[radial-gradient(circle_at_20%_10%,rgba(245,158,11,0.08),transparent_42%),radial-gradient(circle_at_75%_0%,rgba(250,250,249,0.06),transparent_28%),linear-gradient(to_bottom,#111315,#0a0b0d)]"></div>
            <main class="mx-auto max-w-5xl px-6 pb-16 pt-12 md:px-10 md:pt-20">
              <header class="mb-12 border-b border-stone-300/80 pb-8 dark:border-stone-700/80">
                <div class="flex items-center justify-between gap-4">
                  <p class="text-xs uppercase tracking-[0.28em] text-stone-500 dark:text-stone-400">Personal Journal</p>
                  <button type="button" onclick="toggleTheme()" class="rounded-full border border-stone-400/70 px-3 py-1 text-xs font-medium uppercase tracking-[0.14em] text-stone-700 transition hover:border-amber-700/60 hover:text-amber-800 dark:border-stone-600 dark:text-stone-200 dark:hover:border-amber-300 dark:hover:text-amber-200">Toggle Theme</button>
                </div>
                <h1 class="mt-4 max-w-3xl font-display text-4xl leading-[1.05] text-stone-900 dark:text-stone-100 md:text-6xl">Field Notes from Work, Life, and Curious Experiments.</h1>
                <p class="mt-5 max-w-2xl text-base leading-relaxed text-stone-700 dark:text-stone-300 md:text-lg">A handcrafted static journal for essays, shipping logs, and personal observations. Each entry is written in markdown and published with the inkwell CLI.</p>
              </header>
              <section class="grid gap-5 md:grid-cols-2">\(cards)</section>
              \(pagination)
            </main>
          </body>
        </html>
        """
    }

    private func renderCard(_ post: RenderablePost) -> String {
        let chips = renderTaxonomyChips(tags: post.tags, categories: post.categories)
        return """
        <article class="group rounded-2xl border border-stone-300/70 bg-stone-50/60 p-6 shadow-[0_10px_40px_-22px_rgba(28,25,23,0.45)] transition hover:-translate-y-0.5 hover:border-amber-700/40 hover:shadow-[0_18px_50px_-24px_rgba(146,64,14,0.35)] dark:border-stone-700 dark:bg-stone-900/55 dark:shadow-[0_16px_42px_-28px_rgba(0,0,0,0.8)]">
          <p class="text-xs uppercase tracking-[0.22em] text-stone-500 dark:text-stone-400">\(post.date)</p>
          <h2 class="mt-2 font-display text-2xl leading-tight text-stone-900 dark:text-stone-50"><a class="decoration-amber-700/40 underline-offset-4 group-hover:underline" href="/posts/\(post.slug)/">\(post.title)</a></h2>
          <p class="mt-3 text-sm leading-relaxed text-stone-700 dark:text-stone-300">\(post.summary)</p>
          <div class="mt-4 flex flex-wrap gap-2">\(chips)</div>
          <a class="mt-4 inline-flex items-center gap-2 text-sm font-medium text-amber-800 dark:text-amber-300" href="/posts/\(post.slug)/">Read entry <span aria-hidden="true">-></span></a>
        </article>
        """
    }

    private func renderPost(post: RenderablePost, content: String) -> String {
        let chips = renderTaxonomyChips(tags: post.tags, categories: post.categories)
        let coverImage = (post.coverImage?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? "<figure class=\"mt-8 overflow-hidden rounded-2xl border border-stone-300/70 shadow-[0_14px_48px_-28px_rgba(28,25,23,0.6)] dark:border-stone-700\"><img src=\"\(post.coverImage!)\" alt=\"Cover image for \(post.title)\" class=\"h-auto w-full object-cover\"></figure>"
            : ""

        return """
        <html>
          <head>
            <meta charset="utf-8">
            <title>\(post.title)</title>
            <meta name="description" content="\(escapeAttribute(post.summary))">
          </head>
          <body class="antialiased text-stone-800 dark:bg-stone-950 dark:text-stone-100">
            <div class="pointer-events-none fixed inset-0 -z-10 bg-[radial-gradient(circle_at_20%_10%,rgba(245,158,11,0.13),transparent_48%),radial-gradient(circle_at_80%_0%,rgba(28,25,23,0.08),transparent_35%),linear-gradient(to_bottom,#faf7f2,#f4efe7)] dark:bg-[radial-gradient(circle_at_20%_10%,rgba(245,158,11,0.08),transparent_42%),radial-gradient(circle_at_75%_0%,rgba(250,250,249,0.06),transparent_28%),linear-gradient(to_bottom,#111315,#0a0b0d)]"></div>
            <main class="mx-auto max-w-3xl px-6 pb-20 pt-10 md:px-10 md:pt-14">
              <div class="flex items-center justify-between gap-4">
                <a href="/" class="inline-flex items-center gap-2 text-sm font-medium text-amber-800 hover:text-amber-900 dark:text-amber-300 dark:hover:text-amber-200">\u{2190} Back to entries</a>
                <button type="button" onclick="toggleTheme()" class="rounded-full border border-stone-400/70 px-3 py-1 text-xs font-medium uppercase tracking-[0.14em] text-stone-700 transition hover:border-amber-700/60 hover:text-amber-800 dark:border-stone-600 dark:text-stone-200 dark:hover:border-amber-300 dark:hover:text-amber-200">Toggle Theme</button>
              </div>
              <header class="mt-6 border-b border-stone-300/70 pb-6 dark:border-stone-700/70">
                <p class="text-xs uppercase tracking-[0.22em] text-stone-500 dark:text-stone-400">\(post.date)</p>
                <h1 class="mt-3 font-display text-4xl leading-tight text-stone-900 dark:text-stone-100 md:text-5xl">\(post.title)</h1>
                <div class="mt-4 flex flex-wrap gap-2">\(chips)</div>
              </header>
              \(coverImage)
              <article class="post-content mt-8 text-stone-800 dark:text-stone-200">\(content)</article>
            </main>
          </body>
        </html>
        """
    }

    private func buildTaxonomyPages(kind: String, posts: [RenderablePost], extractor: (RenderablePost) -> [String]) -> [BuiltPage] {
        var grouped: [String: [RenderablePost]] = [:]
        for post in posts {
            for value in extractor(post) {
                grouped[value, default: []].append(post)
            }
        }

        return grouped.keys.sorted().map { key in
            let slug = taxonomySlug(key)
            let cards = (grouped[key] ?? []).map(renderCard).joined(separator: "")
            let title = "\(kind.capitalized): \(key)"
            let html = """
            <html>
              <head>
                <meta charset="utf-8">
                <title>\(title)</title>
                <meta name="description" content="Archive page for \(kind) \(escapeAttribute(key)).">
              </head>
              <body class="antialiased text-stone-800 dark:bg-stone-950 dark:text-stone-100">
                <main class="mx-auto max-w-5xl px-6 pb-16 pt-12 md:px-10 md:pt-20">
                  <a href="/" class="text-sm text-amber-800 dark:text-amber-300">\u{2190} Back to home</a>
                  <h1 class="mt-4 font-display text-4xl text-stone-900 dark:text-stone-100">\(title)</h1>
                  <section class="mt-8 grid gap-5 md:grid-cols-2">\(cards)</section>
                </main>
              </body>
            </html>
            """
            return BuiltPage(route: "/\(kind)/\(slug)/", html: html)
        }
    }

    private func renderTaxonomyChips(tags: [String], categories: [String]) -> String {
        let tagChips = tags.prefix(3).map { value in
            let href = "/tags/\(taxonomySlug(value))/"
            return "<a href=\"\(href)\" class=\"rounded-full border border-stone-400/50 px-2.5 py-1 text-[11px] uppercase tracking-[0.12em] text-stone-600 transition hover:border-amber-700/50 hover:text-amber-800 dark:border-stone-600 dark:text-stone-300 dark:hover:border-amber-300 dark:hover:text-amber-200\">\(value)</a>"
        }
        let categoryChips = categories.prefix(2).map { value in
            let href = "/categories/\(taxonomySlug(value))/"
            return "<a href=\"\(href)\" class=\"rounded-full border border-stone-400/50 px-2.5 py-1 text-[11px] uppercase tracking-[0.12em] text-stone-600 transition hover:border-amber-700/50 hover:text-amber-800 dark:border-stone-600 dark:text-stone-300 dark:hover:border-amber-300 dark:hover:text-amber-200\">\(value)</a>"
        }
        return (tagChips + categoryChips).joined(separator: "")
    }

    private func renderPagination(currentPage: Int, totalPages: Int) -> String {
        guard totalPages > 1 else { return "" }
        let links = (1...totalPages).map { page -> String in
            let href = page == 1 ? "/" : "/page/\(page)/"
            let active = page == currentPage
                ? "border-amber-700 bg-amber-100 text-amber-900 dark:border-amber-300 dark:bg-amber-300/15 dark:text-amber-200"
                : "border-stone-300 text-stone-700 hover:border-amber-600 hover:text-amber-800 dark:border-stone-700 dark:text-stone-300 dark:hover:border-amber-300 dark:hover:text-amber-200"
            return "<a href=\"\(href)\" class=\"rounded-full border px-3 py-1 text-sm \(active)\">\(page)</a>"
        }.joined(separator: "")
        return "<nav class=\"mt-10 flex flex-wrap items-center gap-2\" aria-label=\"Pagination\">\(links)</nav>"
    }

    private func taxonomySlug(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func escapeAttribute(_ value: String) -> String {
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
