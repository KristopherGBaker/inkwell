import Foundation

public struct BuiltPage: Equatable {
    public let route: String
    public let html: String

    public init(route: String, html: String) {
        self.route = route
        self.html = html
    }
}

public struct RouteBuilder {
    public init() {}

    public func buildPages(posts: [PostDocument], renderedContent: [String: String]) -> [BuiltPage] {
        var pages: [BuiltPage] = []
        let cards = posts.compactMap { post -> String? in
            guard let slug = post.frontMatter.slug, let title = post.frontMatter.title else { return nil }
            let summary = post.frontMatter.summary ?? "Notes, ideas, and field observations from the journal."
            let date = post.frontMatter.date ?? ""
            let tags = (post.frontMatter.tags ?? []) + (post.frontMatter.categories ?? [])
            let chips = tags.prefix(3).map { value in
                "<span class=\"rounded-full border border-stone-400/50 px-2.5 py-1 text-[11px] uppercase tracking-[0.12em] text-stone-600 dark:border-stone-600 dark:text-stone-300\">\(value)</span>"
            }.joined(separator: "")
            return """
            <article class="group rounded-2xl border border-stone-300/70 bg-stone-50/60 p-6 shadow-[0_10px_40px_-22px_rgba(28,25,23,0.45)] transition hover:-translate-y-0.5 hover:border-amber-700/40 hover:shadow-[0_18px_50px_-24px_rgba(146,64,14,0.35)] dark:border-stone-700 dark:bg-stone-900/55 dark:shadow-[0_16px_42px_-28px_rgba(0,0,0,0.8)]">
              <p class="text-xs uppercase tracking-[0.22em] text-stone-500 dark:text-stone-400">\(date)</p>
              <h2 class="mt-2 font-display text-2xl leading-tight text-stone-900 dark:text-stone-50"><a class="decoration-amber-700/40 underline-offset-4 group-hover:underline" href="/posts/\(slug)/index.html">\(title)</a></h2>
              <p class="mt-3 text-sm leading-relaxed text-stone-700 dark:text-stone-300">\(summary)</p>
              <div class="mt-4 flex flex-wrap gap-2">\(chips)</div>
              <a class="mt-4 inline-flex items-center gap-2 text-sm font-medium text-amber-800 dark:text-amber-300" href="/posts/\(slug)/index.html">Read entry <span aria-hidden=\"true\">-></span></a>
            </article>
            """
        }

        pages.append(BuiltPage(route: "/", html: """
        <html>
          <head>
            <meta charset="utf-8">
            <title>Field Notes</title>
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
                <p class="mt-5 max-w-2xl text-base leading-relaxed text-stone-700 dark:text-stone-300 md:text-lg">A handcrafted static journal for essays, shipping logs, and personal observations. Each entry is written in markdown and published with the blog CLI.</p>
              </header>
              <section class="grid gap-5 md:grid-cols-2">\(cards.joined())</section>
            </main>
          </body>
        </html>
        """))

        for post in posts {
            guard let slug = post.frontMatter.slug, let title = post.frontMatter.title else { continue }
            let content = renderedContent[slug] ?? ""
            let date = post.frontMatter.date ?? ""
            let tags = (post.frontMatter.tags ?? []) + (post.frontMatter.categories ?? [])
            let chips = tags.map {
                "<span class=\"rounded-full border border-stone-400/50 px-2.5 py-1 text-[11px] uppercase tracking-[0.12em] text-stone-600 dark:border-stone-600 dark:text-stone-300\">\($0)</span>"
            }.joined(separator: "")
            let coverImage = (post.frontMatter.coverImage?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? "<figure class=\"mt-8 overflow-hidden rounded-2xl border border-stone-300/70 shadow-[0_14px_48px_-28px_rgba(28,25,23,0.6)] dark:border-stone-700\"><img src=\"\(post.frontMatter.coverImage!)\" alt=\"Cover image for \(title)\" class=\"h-auto w-full object-cover\"></figure>"
                : ""
            let html = """
            <html>
              <head>
                <meta charset="utf-8">
                <title>\(title)</title>
              </head>
              <body class="antialiased text-stone-800 dark:bg-stone-950 dark:text-stone-100">
                <div class="pointer-events-none fixed inset-0 -z-10 bg-[radial-gradient(circle_at_20%_10%,rgba(245,158,11,0.13),transparent_48%),radial-gradient(circle_at_80%_0%,rgba(28,25,23,0.08),transparent_35%),linear-gradient(to_bottom,#faf7f2,#f4efe7)] dark:bg-[radial-gradient(circle_at_20%_10%,rgba(245,158,11,0.08),transparent_42%),radial-gradient(circle_at_75%_0%,rgba(250,250,249,0.06),transparent_28%),linear-gradient(to_bottom,#111315,#0a0b0d)]"></div>
                <main class="mx-auto max-w-3xl px-6 pb-20 pt-10 md:px-10 md:pt-14">
                  <div class="flex items-center justify-between gap-4">
                    <a href="/" class="inline-flex items-center gap-2 text-sm font-medium text-amber-800 hover:text-amber-900 dark:text-amber-300 dark:hover:text-amber-200">\u{2190} Back to entries</a>
                    <button type="button" onclick="toggleTheme()" class="rounded-full border border-stone-400/70 px-3 py-1 text-xs font-medium uppercase tracking-[0.14em] text-stone-700 transition hover:border-amber-700/60 hover:text-amber-800 dark:border-stone-600 dark:text-stone-200 dark:hover:border-amber-300 dark:hover:text-amber-200">Toggle Theme</button>
                  </div>
                  <header class="mt-6 border-b border-stone-300/70 pb-6 dark:border-stone-700/70">
                    <p class="text-xs uppercase tracking-[0.22em] text-stone-500 dark:text-stone-400">\(date)</p>
                    <h1 class="mt-3 font-display text-4xl leading-tight text-stone-900 dark:text-stone-100 md:text-5xl">\(title)</h1>
                    <div class="mt-4 flex flex-wrap gap-2">\(chips)</div>
                  </header>
                  \(coverImage)
                  <article class="post-content mt-8 text-stone-800 dark:text-stone-200">\(content)</article>
                </main>
              </body>
            </html>
            """
            pages.append(BuiltPage(route: "/posts/\(slug)/", html: html))
        }

        return pages
    }
}
