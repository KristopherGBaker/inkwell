# Concepts

How an Inkwell project fits together: the project layout, content types, data files, and themes.

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

## Collections

Collections are content types. Each declared collection has a `dir` (where markdown lives), a `route` (URL prefix), a `sortBy` (default `date`; use `year` for projects, etc.), and optional `taxonomies` (tag/category-style facets, scoped to the collection — `/work/tags/iOS/`, not top-level).

```json
{
  "collections": [
    { "id": "posts", "dir": "content/posts", "route": "/posts" },
    { "id": "projects", "dir": "content/projects", "route": "/work", "sortBy": "year", "taxonomies": ["tags"] }
  ]
}
```

Each collection produces a list page at `<route>/`, detail pages at `<route>/<slug>/`, and per-taxonomy archives at `<route>/<taxonomy>/<slug>/`. Scaffold new items with `inkwell content new <id> "Title"`.

## Child collections

Child collections model a one-to-many relationship (a project and its updates). Give a collection `"parent": "<parentId>"` and `"parentField": "<frontMatterKey>"` (default `parent`). Each child item names its parent's slug in that field and is routed *under* the parent at `<parentRoute>/<parentSlug>/<childSlug>/` — it gets no list or taxonomy pages of its own.

Parent list cards and detail pages receive the child items as `updates` (newest first) plus `updateCount`, `status`, `lastUpdated`, and `relativeUpdated`; each child page gets `project` (its parent) and `siblingNewer`/`siblingOlder`. A child item whose parent slug matches nothing is reported by `inkwell check` (it would otherwise drop silently).

## Home page

The home page has three optional collection-backed sections:

- `featuredCollection` — cards.
- `buildingCollection` — a "what I'm building" feed. Point it at a child/updates collection so each card links to its nested update and names its project.
- `recentCollection` — list.

Each takes a `*Count` and an optional `*Label`/`*Cta`, all translatable via the `translations.<lang>.home` overlay (see [Multi-language](i18n.md)).

## Pages

Pages are markdown files in `content/pages/` whose route comes from their path (`about.md → /about/`, `now/index.md → /now/`). Front-matter `layout: <name>` selects the theme template (default `page`).

## Data files

Data files are YAML/JSON in `data/`, loaded as `data.<basename>` in every template's context (`data/experience.yml` → `data.experience`). Use them for résumé content, link rolls, structured profile data — anything where keeping the content out of markdown is cleaner.

## Themes

Themes ship with the binary; project-side `themes/<name>/templates/` and `themes/<name>/assets/` override on a per-file basis, so you can customize one template without copying the whole theme.

- `default` — the original blog look (Tailwind, amber/stone).
- `quiet` — portfolio-friendly (Fraunces / Manrope / JetBrains Mono, generous whitespace, print-friendly résumé).

Switch with `inkwell theme use <name>`.

## Backward compatibility

A v0.2 `blog.config.json` with no `collections`/`home`/`author`/`nav` keeps the original URL structure verbatim — `/posts/<slug>/`, `/archive/`, top-level `/tags/<slug>/`, paginated `/`. Sites without an `i18n` block stay monolingual.
