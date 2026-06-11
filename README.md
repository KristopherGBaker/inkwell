# Inkwell

A static site generator written in Swift. Write markdown, run one command, get a fast plain-HTML site you can host anywhere. It started as a blog tool and grew into a general publishing tool — it now drives blogs, portfolios, and multilingual sites.

## Install

```bash
brew install KristopherGBaker/tap/inkwell
```

Or run from source:

```bash
git clone https://github.com/KristopherGBaker/inkwell.git
cd inkwell
swift run inkwell --help
```

## Quick start

```bash
inkwell init                     # scaffold a new site in the current directory
inkwell post new "Hello World"   # create a draft post
inkwell serve --watch            # preview locally, rebuilds + live-reloads on save
inkwell build                    # write the site to docs/
inkwell check                    # validate content, links, and assets before deploying
```

That's a working blog. To publish it, the output is a plain static directory — push it to any host, or run `inkwell deploy setup github-pages` to generate a GitHub Pages workflow.

## What it does

- **Blogs and portfolios.** Posts out of the box; add content collections (projects, case studies, updates, …) for portfolio sites, each with its own routes and taxonomies.
- **Pages and data files.** Standalone pages from `content/pages/`, and YAML/JSON in `data/` available to every template — drives data-driven pages like a résumé.
- **Two bundled themes.** `default` for blogs, `quiet` for portfolios. Override any single template file in your project without copying the whole theme.
- **Multi-language.** Opt-in i18n: `foo.md` plus `foo.ja.md` pairs translations automatically, with sensible URLs, hreflang tags, a language switcher, and graceful fallback.
- **Markdown that just works.** GitHub-flavored markdown, Mermaid diagrams, and code highlighting (client-side by default, build-time Shiki optionally).
- **SEO and feeds.** Canonical URLs, Open Graph, sitemap, robots.txt, and RSS/Atom/JSON feeds with zero configuration.

## Documentation

- [Getting started](docs/getting-started.md) — a longer walkthrough: collections, pages, data files, analytics
- [CLI reference](docs/cli.md) — every command, plus GitHub Pages deployment
- [Concepts](docs/concepts.md) — project layout, collections, pages, data files, themes
- [Building a portfolio](docs/portfolio.md) — the `quiet` theme, case studies, and a data-driven résumé
- [Multi-language](docs/i18n.md) — translations, URLs, and fallback behavior
- [Feeds](docs/feeds.md) — RSS/Atom/JSON, per-collection and combined feeds
- [Code highlighting](docs/code-highlighting.md) — enabling build-time Shiki
- [Roadmap](docs/roadmap.md) — what's shipped vs. deferred
- [Contributing](docs/contributing.md) — building, testing, and releasing Inkwell itself

## License

[MIT](LICENSE)
