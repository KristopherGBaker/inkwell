# RFC: Content Collections, Pages, Data, and Theme Templating

## Metadata
- **Status**: Draft
- **Date**: 2026-04-30
- **Author**: Kris
- **Target Version**: v0.3
- **Related**:
  - `docs/roadmap.md` (items #11 Theme Extensibility, #14 Data Files / Computed Content, "content collections beyond standard blog posts")
  - Prototype: `~/Downloads/Personal site - portfolio + blog`

## Summary

Generalize inkwell from "blog posts only" into a small set of generic primitives — **collections**, **pages**, **data files**, **site identity**, **nav**, and a **configurable home** — and move HTML rendering out of inline Swift strings into theme-owned **Stencil** templates. Ship a second theme (`quiet`) that uses these primitives to render a portfolio + blog. Inkwell stays generic; krisbaker.com becomes the first consumer of the new theme.

## Motivation

Inkwell today assumes a single content type (`PostDocument`) and a single site shape (paginated post index → post detail → archive → tags/categories). The home page is hardcoded to a paginated post list. Templates live as inline Swift string literals inside `RouteBuilder`. This is good for a blog and bad for everything else.

The author wants to publish a portfolio (work history, case studies, résumé, about) alongside the existing blog under one site (`krisbaker.com`). The portfolio prototype shows that this needs:

- A second list/detail content type (case studies / "work").
- An art-directed landing page that composes featured items from multiple collections.
- A résumé page built from structured data, not prose.
- A small amount of site-wide identity (name, role, contact, social links) that today's `SiteConfig` doesn't carry.
- Visual treatment beyond the current default theme's reach.

The right response is not to special-case "portfolio" in inkwell. The right response is to introduce the small number of primitives the portfolio happens to need, in a form any future site could reuse. Roadmap items #11 and #14 already point at this.

## Goals

1. Inkwell remains a generic SSG. Zero portfolio-specific concepts in core.
2. Existing blog sites keep working with no config changes. `/posts/<slug>/` URLs are preserved.
3. Sites can declare additional content collections beyond posts.
4. Sites can author standalone pages (about, now, contact) without inventing a route.
5. Sites can supply structured data (YAML/JSON) usable by templates without writing markdown.
6. Themes own page templates as files, not as Swift strings.
7. A new theme (`quiet`) ships with inkwell that demonstrates non-blog use and renders posts, collections, pages, landing, and résumé consistently.
8. krisbaker.com adopts the new theme, gains a portfolio, and keeps its existing posts at `/posts/<slug>/`.

## Non-Goals

- No CMS, hosted editor, or runtime server. (Unchanged from v0.1.)
- No general-purpose template language for arbitrary user expressions beyond what Stencil supplies.
- No incremental builds, image pipeline, scheduled publishing, or multi-language work — those are separate roadmap items.
- No "blocks" / page-builder system on the home page in this cycle. Home composition is template + a small number of config knobs.
- No replacement of the existing default theme. It stays as a minimal blog starter.

## Primitives

### 1. Collections

A collection is a directory of markdown documents that produce a list page and one detail page per item.

**Schema (`blog.config.json`)**

```json
{
  "collections": [
    {
      "id": "posts",
      "dir": "content/posts",
      "route": "/posts",
      "sortBy": "date",
      "sortOrder": "desc",
      "taxonomies": ["tags", "categories"],
      "listTemplate": "post-list",
      "detailTemplate": "post"
    },
    {
      "id": "projects",
      "dir": "content/projects",
      "route": "/work",
      "sortBy": "year",
      "sortOrder": "desc",
      "taxonomies": ["tags"],
      "listTemplate": "work-list",
      "detailTemplate": "case-study"
    }
  ]
}
```

**Behavior**

- Each item becomes `<route>/<slug>/`.
- Each collection generates a list page at `<route>/` (using `listTemplate`).
- Pagination is opt-in per collection: `"paginate": 6` produces `<route>/page/2/` etc. Default is unpaginated.
- **Sort.** `sortBy` is any front-matter field; `sortOrder` is `"asc"` or `"desc"`. Defaults: `sortBy: "date"`, `sortOrder: "desc"`. The special value `"sortBy": "manual"` reads an `order:` integer from each item's front matter and sorts ascending. `inkwell check` warns when items lack the `sortBy` field (those items sink to the bottom of the list).
- **Taxonomies are collection-scoped.** Each collection declares which taxonomies it owns. URLs are `<route>/<taxonomy>/<slug>/` (e.g., `/posts/tags/swift/`, `/work/tags/ios/`). The same tag string in two collections produces two distinct archive pages — same string, different meaning, different URL. Cross-collection aggregate views ("everything tagged Swift across the site") are deferred to a future release.
- Default taxonomies when omitted: `["tags", "categories"]` for any collection. Set `"taxonomies": []` to disable archive page generation for a collection (tags can still be used as visual chips by templates).

**Built-in default**

If `collections` is omitted, inkwell behaves as today: a single `posts` collection at `/posts`, with `tags` + `categories` taxonomies, sorted by `date desc`.

**Rationale for built-in default**: existing inkwell sites keep working with zero config edits. krisbaker.com declares both `posts` (with the home page no longer listing posts) and `projects`.

### 1a. Asset references

All asset paths in front matter (`coverImage`, `shots[]`, future `featuredImage`, etc.) and in `blog.config.json` are **root-absolute** (`/assets/foo.png`) or **fully qualified** (`https://...`). Relative paths (`assets/foo.png`, `./foo.png`, `../foo.png`) are rejected by `inkwell check`.

**Storage convention**: assets live under `static/assets/`. Inkwell's existing static-copy step puts them at output `/assets/...`. Root-absolute references then resolve correctly from any page depth (home `/`, case study `/work/<slug>/`, résumé `/resume/`).

**baseURL handling**: when the site is deployed at a path prefix (e.g., GitHub project pages at `/repo/`), the build prepends the basePath to root-absolute references. Existing `coverImage` logic in `RouteBuilder.swift` is generalized to cover all asset fields.

**Validation**: `inkwell check` extends to verify every `/assets/<path>` reference in front matter resolves to an actual file at `static/assets/<path>`. Missing assets become release blockers, matching today's `coverImage` behavior.

### 2. Pages

A page is a single markdown document with no list view.

**Layout**: `content/pages/about.md` → `/about/`. Nesting reflected in URL: `content/pages/now/index.md` → `/now/`.

**Front matter**

```yaml
---
title: About
layout: page          # selects template; defaults to "page"
description: ...      # used for og/meta
---
```

`layout` resolves against the active theme's templates. Themes can ship custom layouts (e.g., `quiet` adds `landing`, `resume`, `contact`).

**Data-driven pages.** A page can have an empty markdown body and rely entirely on data files for content. The mechanism is unchanged: a one-file shell in `content/pages/` declares the route and metadata; the chosen template ignores `page.content` and reads from `data.*` instead. This is how the résumé is generated:

```yaml
---
title: Résumé
slug: resume
layout: resume
description: 13 years building consumer iOS apps used by millions.
---
```

Combined with `data/experience.yml`, `data/competencies.yml`, `data/education.yml`, the `quiet` theme's `resume` template renders the page entirely from data. The shell file's only job is to declare the route, the template choice, and the page metadata (title, description, canonical URL) the same way every other page does.

**Why a shell file rather than theme-declared synthetic routes**: every site URL traces back to a single content file in `content/pages/` or `content/<collection>/`. There is no second routing mechanism, no "this theme also generates these routes" surprise, and no requirement-checking in core ("does `data.experience` exist?"). The cost — one four-line file per data-driven page — is trivial; the clarity benefit is large.

### 3. Data files

A `data/` directory at the project root. Files are loaded by extension (`.yml`, `.yaml`, `.json`) and exposed in the template context under `data.<basename>`.

```
data/
  experience.yml      → context.data.experience
  competencies.yml    → context.data.competencies
  education.yml       → context.data.education
```

Templates can iterate or read scalar values directly. There is no schema validation in v0.3 beyond "is it valid YAML/JSON"; that's a follow-up.

### 4. Site identity (`SiteConfig.author`)

Extend `SiteConfig` with a typed, optional author block.

```swift
public struct AuthorConfig: Codable, Equatable {
    public var name: String
    public var role: String?
    public var location: String?
    public var email: String?
    public var social: [SocialLink]?
}

public struct SocialLink: Codable, Equatable {
    public var label: String     // "LinkedIn"
    public var url: String       // "https://linkedin.com/in/..."
}
```

Usage in `blog.config.json`:

```json
{
  "author": {
    "name": "Kristopher Baker",
    "role": "Senior Software Engineer",
    "location": "Tokyo, Japan",
    "email": "kris@krisbaker.com",
    "social": [
      { "label": "LinkedIn", "url": "https://linkedin.com/in/kristophergbaker" },
      { "label": "GitHub",   "url": "https://github.com/kristophergbaker" }
    ]
  }
}
```

Available in template context as `site.author`.

**Why typed config and not `data/site.yml`**: identity is small, stable, used by every page, and benefits from compile-time field stability. Data files are for iterable, schema-less, theme-specific structures.

### 5. Nav

Header navigation declared in config:

```json
{
  "nav": [
    { "label": "Work",    "route": "/work/" },
    { "label": "Writing", "route": "/posts/" },
    { "label": "About",   "route": "/about/" },
    { "label": "Résumé",  "route": "/resume/" }
  ]
}
```

Available as `site.nav` in templates. Themes are free to render or ignore it; the new theme renders it as a sticky top bar.

### 6. Configurable home

```json
{
  "home": {
    "template": "landing",
    "featuredCollection": "projects",
    "featuredCount": 4,
    "recentCollection": "posts",
    "recentCount": 2
  }
}
```

When `home` is omitted, the build runs the legacy path: paginated post list at `/`, identical to today's behavior.

When `home` is present, `template` selects a theme template and the remaining fields populate context as `home.featured` (a sorted slice of the featured collection) and `home.recent` (a sorted slice of the recent collection).

**Rationale for fixed knobs vs. a blocks system**: a blocks system is more flexible but requires schema design, validation, and a richer template loop. For one consumer site whose layout is already designed, fixed knobs ship in days, not weeks. We can add `blocks` later as an additive alternative if a second site needs it.

## Templating Migration

This is the load-bearing change. Without it, items 1–6 would each compound the inline-string problem in `RouteBuilder`.

### Engine: Stencil

[Stencil](https://github.com/stencilproject/Stencil) is the closest fit to Swift, has stable Codable-friendly context handling, and supports template inheritance. Alternatives considered:

- **Mustache**: too logic-light for the conditionals we need (paginated vs not, featured collection present, social links optional).
- **Leaf**: tied to Vapor's release cadence; heavier dependency for a CLI.
- **Hand-rolled**: rejected — we're moving away from inline string assembly precisely to avoid this.

### Theme template layout

```
themes/<name>/
  theme.json
  templates/
    base.html              # shared <html><head><body> shell
    partials/
      head.html            # meta, og, canonical, head fragment injection
      top-bar.html
      footer.html
      taxonomy-chips.html
    layouts/
      landing.html         # home page
      post.html            # blog post detail
      page.html            # generic markdown page
      case-study.html      # project detail
      resume.html          # data-driven résumé
      post-list.html       # collection list (posts)
      work-list.html       # collection list (projects)
      taxonomy.html        # tag/category page
      404.html
  assets/                  # tailwind output, theme-specific css/js
```

The default theme keeps working: it ships a minimal set of templates (`base`, `landing` falling back to paginated posts, `post`, `taxonomy`, `404`).

### Render-time architecture

Today: `RouteBuilder.buildPages` builds `[BuiltPage]` of route + html in one step.

After: split into

1. **`PageContextBuilder`** — builds `(route, templateName, context)` triples. No HTML.
2. **`TemplateRenderer`** — Stencil-backed; resolves theme + template name, fills context, returns `BuiltPage`.

Plugin hooks unchanged. Output writer unchanged.

### Context shape (sketch)

```yaml
site:
  title, description, tagline, baseURL, theme, searchEnabled
  author: { name, role, location, email, social[] }
  nav: [{ label, route }]
data:
  <name>: <yaml/json contents>
collections:
  <id>: { items: [...], route, count }
page:
  type: "post" | "page" | "case-study" | "landing" | "resume" | "taxonomy" | "404"
  route, title, description, canonicalURL
  frontMatter: { ... }
  content: <rendered HTML body, present for markdown-backed pages>
home:
  featured: [...]   # only when on landing
  recent: [...]
collection:
  id, item        # on detail pages
  items, page, totalPages   # on list pages
```

### Migration cost

Roughly:

- Add Stencil dependency, theme template loader, `TemplateRenderer`.
- Move every render function in `RouteBuilder.swift` into a `.html` file in `themes/default/templates/`. Existing inline HTML transfers nearly verbatim — the templating syntax replaces the string interpolation.
- Update existing tests to assert on context (or render-then-snapshot) rather than substring-matching against `RouteBuilder` output.
- Net Swift LOC drops; theme files grow accordingly.

This is the largest single change in v0.3 and the highest source of risk. Mitigation: land it as a standalone PR with the default theme rendering identical output, before any portfolio features are added.

## Theme Strategy

Two themes ship with inkwell:

1. **`themes/default`** — minimal, blog-only. Paginated post list home, post detail, archive, tags/categories. Lives unchanged structurally; only its inline HTML moves into template files.
2. **`themes/quiet`** — full-featured. Renders all page types: landing, post, case-study, page, resume, taxonomy, 404. Typography stack: Fraunces (display, italic), Manrope (body), JetBrains Mono. Tokens and component classes lifted from the prototype's `tokens.css` and `extra-styles.css`. Uses CSS custom properties on `[data-theme="light|dark"]`. Owns a print stylesheet for `resume`.

**krisbaker.com** sets `"theme": "quiet"` and gets the new look across both blog and portfolio. The two existing posts re-render with new typography under their existing `/posts/<slug>/` URLs — no link breakage.

## krisbaker.com Layout (Concrete)

```
krisbaker.com/
  blog.config.json
  head.html
  content/
    posts/
      <existing posts>.md
    projects/
      wolt-membership.md
      smartnews-ios.md
      aside.md
      bodybuilding.md
    pages/
      about.md
      resume.md            # empty-body shell with `layout: resume`;
                           # body is unused, content comes from data/*.yml
  data/
    experience.yml
    competencies.yml
    education.yml
  static/
    assets/
      portrait.png
      mock-wolt-1.png
      ...
```

Example `blog.config.json`:

```json
{
  "title": "Kristopher Baker",
  "description": "Senior Software Engineer · iOS · Growth · AI · Tokyo",
  "baseURL": "https://krisbaker.com/",
  "theme": "quiet",
  "outputDir": "docs",
  "head": "head.html",
  "author": {
    "name": "Kristopher Baker",
    "role": "Senior Software Engineer",
    "location": "Tokyo, Japan",
    "email": "kris@krisbaker.com",
    "social": [
      { "label": "LinkedIn", "url": "https://linkedin.com/in/kristophergbaker" },
      { "label": "GitHub",   "url": "https://github.com/kristophergbaker" }
    ]
  },
  "nav": [
    { "label": "Work",    "route": "/work/" },
    { "label": "Writing", "route": "/posts/" },
    { "label": "About",   "route": "/about/" },
    { "label": "Résumé",  "route": "/resume/" }
  ],
  "collections": [
    { "id": "posts",    "dir": "content/posts",    "route": "/posts", "sortBy": "date", "sortOrder": "desc", "taxonomies": ["tags", "categories"] },
    { "id": "projects", "dir": "content/projects", "route": "/work",  "sortBy": "year", "sortOrder": "desc", "taxonomies": ["tags"] }
  ],
  "home": {
    "template": "landing",
    "featuredCollection": "projects",
    "featuredCount": 4,
    "recentCollection": "posts",
    "recentCount": 2
  }
}
```

Example project front matter (`content/projects/wolt-membership.md`):

```yaml
---
title: Rebuilding the membership funnel for a quarter-million subscribers
slug: wolt-membership
year: "2023 — Now"
sortYear: 2023
org: Wolt / DoorDash
role: Senior Software Engineer · Membership Growth
brand: wolt
summary: Lead engineer for Wolt+ growth. +29.8% sign-ups, +27,000 incremental subscribers/yr — through experimentation, telemetry, and ruthless attention to checkout friction.
tags: [iOS, Growth, Subscription, A/B testing, BDUI]
shots:
  - /assets/mock-wolt-1.png
  - /assets/mock-wolt-2.png
  - /assets/wolt-plus-subscribe.png
metrics:
  - { value: "+29.8%", label: "incremental sign-ups" }
  - { value: "+27k",   label: "subscribers / yr" }
  - { value: "3",      label: "frontend DRI launches" }
---

(case study body in markdown)
```

Example data file (`data/experience.yml`):

```yaml
- org: Wolt / DoorDash
  role: Senior Software Engineer
  years: 2023 — Now
  location: Tokyo, Japan
  bullets:
    - Lead engineer for membership growth ...
    - Led implementation of subscription funnel improvements ...
- org: SmartNews
  ...
```

## Migration Steps

Land in this order, each as a self-contained change set:

1. **Templating spike** — add Stencil, build `TemplateRenderer`, port `default` theme's HTML to `templates/`. Verify byte-identical (or trivially-different) output against current build for the existing example site. Tests updated to context-level assertions where practical.
2. **`SiteConfig` extensions** — add `author`, `nav`, `home`, `collections`. All optional. Add fixtures.
3. **Generic collections** — refactor `ContentLoader` to load any declared collection; refactor `RouteBuilder` (now `PageContextBuilder`) to emit list/detail pages per collection. `posts` becomes an implicit collection when none declared. Keep tag/category routing scoped to the owning collection.
4. **Pages** — load `content/pages/`, route by relative path, render with `layout` template.
5. **Data files** — load `data/*.{yml,yaml,json}` into context.
6. **Configurable home** — when `home` is set, render the chosen template instead of the paginated post index.
7. **`themes/quiet`** — author all templates, port tokens/component classes from prototype, ship Fraunces/Manrope/JetBrains font loading, print stylesheet for resume.
8. **krisbaker.com cutover** — author project markdown (port prose from prototype's `CaseBody`), data files, pages; switch `theme` to `quiet`; verify post URLs unchanged, sitemap/RSS regenerated.

Each step ships green tests and a working example site. v0.3 is "all of the above merged."

## CLI Changes

Two additive CLI changes in v0.3:

1. **`inkwell content new <collection> "Title"`** — generic content scaffolder. Reads the collection definition from `blog.config.json` to determine target dir, route prefix, and front-matter scaffold. Slugifies title the same way `post new` does today. Each collection definition may declare an optional `scaffold` (path to a YAML or markdown template file); when omitted, fall back to minimal defaults: `title`, `slug`, `date` for date-sorted collections; `title`, `slug`, `year` for year-sorted collections.

2. **`inkwell post new "Title"`** — preserved as a thin alias for `inkwell content new posts "Title"`. Existing scripts, docs, and skills continue to work unchanged.

Implementation: a new `Sources/BlogCLI/Commands/ContentNewCommand.swift`; `PostNewCommand.swift` becomes a deprecated-by-policy wrapper that delegates. Skills under `skills/blog-cli/subskills/` gain a sibling `content-new.md`; existing `post-new.md` adds a "for non-post collections, use `content new`" note.

## Authoring Tooling

A `portfolio-data` agent skill ships with inkwell to help users populate `data/experience.yml`, `data/competencies.yml`, `data/education.yml`, and the `author` block in `blog.config.json` from existing source material (résumé PDF, LinkedIn export, plain-text CV, or pasted notes). The skill is portable across Claude Code, Codex, and other agents that read SKILL.md frontmatter for discovery; subskill bodies are plain markdown describing extraction rules, schemas, and pitfalls.

Lives at `skills/portfolio-data/` and is registered via `.claude-plugin/marketplace.json`. See `skills/portfolio-data/SKILL.md` for the workflow.

## Backward Compatibility

- `blog.config.json` fields are all optional additions. Existing configs keep parsing.
- The current `posts`-only behavior is preserved when `collections` is omitted.
- `/posts/<slug>/` is preserved on krisbaker.com (the existing collection's `route` is `/posts`).
- The `default` theme's rendered output is preserved through the templating migration (visual diff verified before merge).
- `inkwell post new` keeps working. A future `inkwell content new <collection>` is a v0.4 nicety.

## Out of Scope (deferred)

- A blocks / page-builder model for the home page.
- Schema validation for data files.
- Multi-language support (separate RFC, 2026-04-01).
- Image pipeline / responsive images.
- Author switching, multi-author bylines.
- Theme marketplace / installable themes beyond the bundled two.
- Replacing or evolving `themes/default` typography.

## Resolved Questions

- **Résumé route generation.** Use a one-file shell at `content/pages/resume.md` with `layout: resume` and an empty body. The route comes from the file's existence; the page content comes from data files. No theme-declared synthetic routes, no implicit generation. See "Data-driven pages" under Primitives §2.
- **Taxonomies are collection-scoped.** URLs are `<collection.route>/<taxonomy>/<slug>/`. Same tag string in two collections produces two distinct archive pages. No legacy `/tags/<x>/` redirects — krisbaker.com's existing posts had no tags, and there are no other inkwell users to migrate. Cross-collection aggregate views deferred. See Primitives §1 "Behavior".
- **CLI shape.** Add `inkwell content new <collection> "Title"` as the generic scaffolder; keep `inkwell post new` as an alias. See "CLI Changes".
- **Sort keys.** Generic `sortBy` (any front-matter field) + `sortOrder` (`asc` / `desc`), with `sortBy: "manual"` reading a per-item `order:` integer. Defaults: `sortBy: "date"`, `sortOrder: "desc"`. See Primitives §1 "Behavior".
- **Asset paths.** Root-absolute (`/assets/...`) or fully qualified (`https://...`). Relative paths rejected by `inkwell check`. Storage convention: `static/assets/`. See Primitives §1a.

## Success Criteria

The RFC succeeds when:

- An existing inkwell blog rebuilds with no config changes and produces the same site.
- A new site can declare additional collections, pages, and data files without writing Swift.
- krisbaker.com renders a portfolio + blog under one theme, with case studies, a landing page, a printable résumé, and the existing posts at their original URLs.
- A second theme can be authored without modifying inkwell core.
