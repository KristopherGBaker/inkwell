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
            return """
            <article class="group rounded-2xl border border-stone-300/70 bg-stone-50/60 p-6 shadow-[0_10px_40px_-22px_rgba(28,25,23,0.45)] transition hover:-translate-y-0.5 hover:border-amber-700/40 hover:shadow-[0_18px_50px_-24px_rgba(146,64,14,0.35)]">
              <p class="text-xs uppercase tracking-[0.22em] text-stone-500">\(date)</p>
              <h2 class="mt-2 font-display text-2xl leading-tight text-stone-900"><a class="decoration-amber-700/40 underline-offset-4 group-hover:underline" href="/posts/\(slug)/">\(title)</a></h2>
              <p class="mt-3 text-sm leading-relaxed text-stone-700">\(summary)</p>
              <a class="mt-4 inline-flex items-center gap-2 text-sm font-medium text-amber-800" href="/posts/\(slug)/">Read entry <span aria-hidden=\"true\">-></span></a>
            </article>
            """
        }

        pages.append(BuiltPage(route: "/", html: """
        <html>
          <head>
            <meta charset="utf-8">
            <title>Field Notes</title>
          </head>
          <body class="antialiased">
            <div class="pointer-events-none fixed inset-0 -z-10 bg-[radial-gradient(circle_at_20%_10%,rgba(245,158,11,0.13),transparent_48%),radial-gradient(circle_at_80%_0%,rgba(28,25,23,0.08),transparent_35%),linear-gradient(to_bottom,#faf7f2,#f4efe7)]"></div>
            <main class="mx-auto max-w-5xl px-6 pb-16 pt-12 md:px-10 md:pt-20">
              <header class="mb-12 border-b border-stone-300/80 pb-8">
                <p class="text-xs uppercase tracking-[0.28em] text-stone-500">Personal Journal</p>
                <h1 class="mt-4 max-w-3xl font-display text-4xl leading-[1.05] text-stone-900 md:text-6xl">Field Notes from Work, Life, and Curious Experiments.</h1>
                <p class="mt-5 max-w-2xl text-base leading-relaxed text-stone-700 md:text-lg">A handcrafted static journal for essays, shipping logs, and personal observations. Each entry is written in markdown and published with the blog CLI.</p>
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
            let html = """
            <html>
              <head>
                <meta charset="utf-8">
                <title>\(title)</title>
              </head>
              <body class="antialiased">
                <div class="pointer-events-none fixed inset-0 -z-10 bg-[radial-gradient(circle_at_20%_10%,rgba(245,158,11,0.13),transparent_48%),radial-gradient(circle_at_80%_0%,rgba(28,25,23,0.08),transparent_35%),linear-gradient(to_bottom,#faf7f2,#f4efe7)]"></div>
                <main class="mx-auto max-w-3xl px-6 pb-20 pt-10 md:px-10 md:pt-14">
                  <a href="/" class="inline-flex items-center gap-2 text-sm font-medium text-amber-800 hover:text-amber-900">\u{2190} Back to entries</a>
                  <header class="mt-6 border-b border-stone-300/70 pb-6">
                    <p class="text-xs uppercase tracking-[0.22em] text-stone-500">\(date)</p>
                    <h1 class="mt-3 font-display text-4xl leading-tight text-stone-900 md:text-5xl">\(title)</h1>
                  </header>
                  <article class="post-content mt-8 text-stone-800">\(content)</article>
                </main>
              </body>
            </html>
            """
            pages.append(BuiltPage(route: "/posts/\(slug)/", html: html))
        }

        return pages
    }
}
