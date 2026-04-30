# Inkwell

Static site generator written in Swift. Started as a personal blog tool; v0.3 generalizes it into a publishing tool that can also drive portfolios — multiple content collections, standalone pages, static data files, configurable home page, and themes.

## Features

- **Content collections.** Configure any number of content types in `blog.config.json` (posts, projects, notes, …); each gets its own list, detail, and taxonomy routes.
- **Standalone pages.** Drop markdown into `content/pages/` for one-off pages like `/about/` or `/now/`.
- **Static data files.** YAML/JSON in `data/` is exposed to every template — drives data-driven pages like a résumé.
- **Configurable home.** Pull featured + recent items from any collection into the landing page via a `home` config block.
- **Themes.** Two themes bundled (`default` for blogs, `quiet` for portfolios + blogs). Stencil templates, project-side files override bundled ones per file.
- **Authoring CLI.** `init`, `post new`, `content new`, `build`, `serve --watch`, `check`, `theme`, `deploy`.
- **Markdown.** GFM (tables, task lists, strikethrough, alerts, fenced code) plus Mermaid blocks; build-time syntax highlighting with Shiki.
- **SEO + feeds.** Canonical URLs, Open Graph, Twitter cards, sitemap.xml, robots.txt, RSS, search index.
- **Static deploy.** GitHub Pages workflow generator built in; output is a plain directory you can deploy anywhere.

## Install

Homebrew (recommended):

```bash
brew tap KristopherGBaker/tap && brew install inkwell
```

Mint:

```bash
brew install mint
mint install KristopherGBaker/inkwell
```

Or run without installing: `mint run KristopherGBaker/inkwell inkwell <subcommand>`.

## Quick start — blog

```bash
inkwell init
inkwell post new "Hello World"
inkwell serve --watch        # rebuilds + live-reloads on save
inkwell build                # writes to docs/
inkwell check                # validates content + links + assets
```

`serve --watch` rebuilds when you edit posts, theme files, `blog.config.json`, or anything in `public/` and `static/`. The home page links to `/archive/`; both paginate published posts newest first.

## Quick start — portfolio

```bash
inkwell init
# edit blog.config.json: set theme, add author/nav/home/collections
inkwell content new projects "Wolt Membership"
# add data/experience.yml, data/competencies.yml, data/education.yml
inkwell build
inkwell check
```

Example `blog.config.json` for a portfolio:

```json
{
  "title": "Kristopher Baker",
  "baseURL": "https://krisbaker.com/",
  "theme": "quiet",
  "outputDir": "docs",
  "tagline": "Tokyo · Available for new conversations",
  "author": {
    "name": "Kristopher Baker",
    "role": "Senior Software Engineer",
    "location": "Tokyo, Japan",
    "social": [{ "label": "GitHub", "url": "https://github.com/KristopherGBaker" }]
  },
  "nav": [
    { "label": "Work", "route": "/work/" },
    { "label": "Writing", "route": "/posts/" },
    { "label": "Résumé", "route": "/resume/" }
  ],
  "home": {
    "template": "landing",
    "featuredCollection": "projects",
    "featuredCount": 4,
    "recentCollection": "posts",
    "recentCount": 2
  },
  "collections": [
    { "id": "posts", "dir": "content/posts", "route": "/posts" },
    {
      "id": "projects",
      "dir": "content/projects",
      "route": "/work",
      "sortBy": "year",
      "taxonomies": ["tags"],
      "detailTemplate": "layouts/case-study"
    }
  ]
}
```

For the résumé page, drop a one-liner shell into `content/pages/resume.md`:

```markdown
---
title: Résumé
layout: resume
---
```

The `resume` layout reads from `data/experience.yml`, `data/competencies.yml`, and `data/education.yml`. The `portfolio-data` agent skill walks Claude Code (or Codex) through importing your existing résumé into those files.

## Concepts

- **Collections** are content types. Each declared collection has a `dir` (where markdown lives), a `route` (URL prefix), a `sortBy` (default `date`; use `year` for projects, etc.), and optional `taxonomies` (tag/category-style facets, scoped to the collection — `/work/tags/iOS/`, not top-level).
- **Pages** are markdown files in `content/pages/` whose route comes from their path (`about.md → /about/`, `now/index.md → /now/`). Front-matter `layout: <name>` selects the theme template.
- **Data files** are YAML/JSON in `data/`, loaded as `data.<basename>` in every template's context. Use them for résumé content, link rolls, structured profile data — anything where keeping the content out of markdown is cleaner.
- **Themes** ship with the binary; project-side `themes/<name>/templates/` and `themes/<name>/assets/` override on a per-file basis. The `default` theme keeps the v0.2 blog look (Tailwind, amber/stone). The `quiet` theme is portfolio-friendly (Fraunces / Manrope / JetBrains Mono, generous whitespace, print-friendly résumé).
- **Backward compatibility.** A v0.2 `blog.config.json` with no `collections`/`home`/`author`/`nav` keeps today's URL structure verbatim — `/posts/<slug>/`, `/archive/`, top-level `/tags/<slug>/`, paginated `/`.

## CLI reference

| Command | What it does |
|---------|--------------|
| `inkwell init` | Scaffold a new project in the current directory |
| `inkwell post new "<title>"` | Create a new draft post in `content/posts/` |
| `inkwell post list` | List posts and their state |
| `inkwell post publish <slug>` | Flip a post from `draft: true` to `false` |
| `inkwell content new <collection> "<title>"` | Scaffold a new item in any declared collection |
| `inkwell build` | Build the site to `outputDir` (default `docs/`) |
| `inkwell serve [--watch]` | Local dev server with optional rebuild + live reload |
| `inkwell check` | Validate front matter, asset paths, links, taxonomy collisions |
| `inkwell theme use <name>` | Switch the active theme in `blog.config.json` |
| `inkwell deploy setup github-pages` | Generate the Pages workflow |

## Project layout

```
my-site/
├── blog.config.json
├── content/
│   ├── posts/                # blog posts (the legacy collection)
│   ├── projects/             # any other declared collection
│   └── pages/
│       └── about.md          # → /about/
├── data/
│   ├── experience.yml        # → data.experience in templates
│   └── education.yml
├── public/                   # copied verbatim into the output root
├── static/                   # alternate copy-verbatim location; static/assets/ is canonical for /assets/...
├── themes/
│   └── quiet/                # only present if you're overriding bundled templates/assets
└── docs/                     # build output (gitignore'd or committed for Pages)
```

Asset references in front matter (`coverImage`, `shots`, `featuredImage`, `ogImage`, `thumbnail`) should be `/assets/...` (resolved from `static/assets/` or `public/assets/`) or fully-qualified `https://...` URLs. Relative paths like `assets/foo.png` are rejected by `inkwell check`.

## Optional GitHub Pages setup

```bash
inkwell init
inkwell deploy setup github-pages
```

Review `baseURL` in `blog.config.json` for your Pages URL before publishing. The setup is optional and does not rewrite existing config.

## Run from source

```bash
git clone https://github.com/KristopherGBaker/inkwell.git
cd inkwell
swift run inkwell init /path/to/site
swift run inkwell build
```

## Developer tooling

```bash
make brew-strap        # install local tooling via Brewfile
make bootstrap-mint    # install Mint-managed tools (SwiftLint, etc.)
npm ci                 # install shiki for syntax highlighting in tests
make verify            # lint + tests
```

`make verify` defaults to a Mint-managed SwiftLint pin. Override with `SWIFTLINT=swiftlint make verify` if you have it on PATH.

## Documentation

- `docs/getting-started.md` — extended walkthrough, including v0.3 features
- `docs/roadmap.md` — what's shipped vs. deferred
- `docs/rfcs/` — design decisions; v0.3's source of truth is `docs/rfcs/2026-04-30-content-collections-and-templating.md`
- `docs/plans/` — TDD-driven implementation plans
- `CLAUDE.md` — agent guide for working in this repo
