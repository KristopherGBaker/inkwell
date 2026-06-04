---
name: site-setup
description: Use when a user is starting a new inkwell project (or upgrading from v0.2 to v0.3) and needs `blog.config.json` configured for their use case — blog only, portfolio only, or blog + portfolio. Walks through choosing a theme, declaring collections, setting site identity, and bootstrapping first content. Triggers on "set up an inkwell site", "configure my portfolio", "switch from default to quiet theme", "add projects to my blog".
---

# Inkwell Site Setup

Use this skill to walk a user through the initial configuration of an inkwell project: picking a theme, deciding on collections, populating site identity, and dropping in their first piece of content. The output is a complete, buildable `blog.config.json` plus enough scaffolded files that `inkwell build && inkwell check` succeed.

## When To Use

- User just ran `inkwell init` and wants help filling in `blog.config.json`.
- User has an existing v0.2 blog and wants to add a portfolio (projects + résumé) without breaking existing post URLs.
- User asks "how do I configure inkwell for X" where X is a portfolio site, a multi-collection site, or a non-blog use case.

## Decision Tree (ask the user)

1. **What kind of site?**
   - Blog only → use the blog config. No `collections` key needed; v0.2 behavior applies (top-level paginated landing, `/archive/`, `/posts/<slug>/`, top-level `/tags/<slug>/`).
   - Portfolio only → use the portfolio config. `collections: [{ id: "projects", ... }]`, `home` block drives `/`.
   - Blog + portfolio (most common for the krisbaker.com pattern) → use the combined config below.
2. **Theme?**
   - Blog → `default` (Tailwind, amber/stone, search box, paginated landing).
   - Portfolio or combined → `quiet` (Fraunces / Manrope serif palette, generous whitespace, print-friendly résumé layout).
3. **Existing posts?** If yes, preserve the legacy `/posts/<slug>/` URLs. The combined config's `posts` collection at `route: "/posts"` does that automatically.
4. **Résumé page?** If yes, you'll need `content/pages/resume.md` with `layout: resume` plus `data/experience.yml`, `data/competencies.yml`, `data/education.yml`. Hand off to the `portfolio-data` skill once the rest of the config is settled.

## Recommended Configs

### Blog only (v0.2 behavior preserved)

```json
{
  "title": "Field Notes",
  "baseURL": "https://example.com/",
  "theme": "default",
  "outputDir": "docs",
  "description": "Notes from the bench."
}
```

That's it — no `collections`, no `home`. Legacy posts code path emits everything.

### Portfolio + blog (combined, krisbaker.com pattern)

```jsonc
{
  "title": "Kristopher Baker",
  "baseURL": "https://krisbaker.com/",
  "theme": "quiet",
  "outputDir": "docs",
  "tagline": "Tokyo · Available for new conversations",
  "brandIcon": {                                              // optional — image mark for the top-bar
    "light": "/assets/icons/kb.png",
    "dark":  "/assets/icons/kb-dark.png"
  },
  "author": {
    "name": "Kristopher Baker",
    "role": "Senior Software Engineer",
    "location": "Tokyo, Japan",
    "email": "kris@example.com",
    "portrait": "/assets/portraits/about.jpg",                // optional — about page formal portrait
    "social": [
      { "label": "GitHub", "url": "https://github.com/USERNAME" },
      { "label": "LinkedIn", "url": "https://linkedin.com/in/USERNAME" }
    ]
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

URLs produced: `/`, `/posts/`, `/posts/<slug>/`, `/posts/tags/<slug>/`, `/work/`, `/work/<slug>/`, `/work/tags/<slug>/`, plus pages from `content/pages/`.

### Portfolio only (no blog)

Same as combined, but drop the `posts` entry from `collections` and the `recentCollection` from `home`:

```json
{
  "home": { "template": "landing", "featuredCollection": "projects", "featuredCount": 6 },
  "collections": [
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

### Building section (projects + updates, via child collections)

Add this when the user wants to show what they are *actively building* — personal projects that each accumulate a stream of lightweight progress updates, distinct from polished `work` case studies. It uses a **child collection**: `updates` declares `parent: "building"`, so each update is routed under its project and surfaces on the project's timeline.

```jsonc
{
  "nav": [
    { "label": "Work", "route": "/work/" },
    { "label": "Building", "route": "/building/" },     // between Work and Writing
    { "label": "Writing", "route": "/posts/" }
  ],
  "home": {
    "template": "landing",
    "featuredCollection": "projects", "featuredCount": 4,
    "buildingCollection": "updates", "buildingCount": 3, // "what I'm building" feed
    "recentCollection": "posts", "recentCount": 2
  },
  "collections": [
    { "id": "building", "dir": "content/building", "route": "/building",
      "sortBy": "order", "sortOrder": "asc", "taxonomies": ["tags"],
      "listTemplate": "layouts/building-list", "detailTemplate": "layouts/building" },
    { "id": "updates", "dir": "content/updates", "route": "/building",
      "parent": "building", "parentField": "project",
      "sortBy": "date", "sortOrder": "desc", "taxonomies": [],
      "detailTemplate": "layouts/update" }
  ]
}
```

- **Project front matter** (`content/building/<slug>.md`): `title`, `slug`, `order`, optional `status` (`active`/`shipped`/`paused`/`exploring`, default `active`), `summary`, `tags`, `repo`, `coverImage`.
- **Update front matter** (`content/updates/YYYY-MM-DD-<slug>.md`): `title`, `slug`, `date`, `project` (the parent slug), optional `status` (`shipped`/`wip`/`note`/`decision`). Scaffold with `inkwell content new updates "Title"`.
- URLs produced: `/building/`, `/building/<project>/`, `/building/<project>/<update>/`, `/building/tags/<slug>/`.
- The `quiet` theme ships the `building-list`, `building`, and `update` layouts plus the living-changelog CSS (status dots, update timeline). Translate the building label/CTA via `translations.<lang>.home` and back-link/section copy via `translations.<lang>.themeCopy` (`buildingBack`, `buildingUpdates`, `updateNewer`, `updateOlder`).

## Workflow

1. Confirm the user's goals (blog vs portfolio vs combined; preserve existing URLs?).
2. Show the proposed `blog.config.json` for their case. **Don't write it yet — let them edit fields like `title`, `baseURL`, `author`, social URLs.**
3. Once confirmed, write `blog.config.json`.
4. Scaffold the first piece of content:
   - For a portfolio: `inkwell content new projects "<First Project>"`. Edit the front matter to fill in `summary`, `metrics`, `shots`. Then write the body.
   - For a blog post: `inkwell post new "<First Post>"`. Edit the body, then `inkwell post publish <slug>`.
   - For a résumé page: write `content/pages/resume.md` (a one-liner shell with `layout: resume` and an empty body), then hand off to `portfolio-data` to populate `data/*.yml`.
5. Build + check:
   ```bash
   inkwell build
   inkwell check
   inkwell serve --watch
   ```
6. Open the preview, eyeball the output, iterate on copy.

## Collection Schema Cheat Sheet

```jsonc
{
  "id":              "projects",          // unique key; referenced by content new and home.featuredCollection
  "dir":             "content/projects",  // where its markdown files live
  "route":           "/work",             // URL prefix — also where taxonomies live (/work/tags/<slug>/)
  "sortBy":          "year",              // "date" (default) or "year" or any front-matter field
  "sortOrder":       "desc",              // "desc" (default) or "asc"
  "taxonomies":      ["tags"],            // omit to default to ["tags", "categories"]
  "paginate":        null,                // not yet implemented in v0.3
  "listTemplate":    "layouts/work-list", // optional override; default "layouts/post-list"
  "detailTemplate":  "layouts/case-study", // optional override; default "layouts/post"
  "parent":          null,                // set to another collection's id to make this a child collection
  "parentField":     "parent",            // front-matter key on child items naming the parent slug (default "parent")
  "scaffold":        null                 // optional path to a custom scaffold template (future)
}
```

A collection with `parent` set is a **child collection**: its items route under the matching parent item at `<parentRoute>/<parentSlug>/<childSlug>/`, get no list/taxonomy pages of their own, and appear on the parent's detail page as a newest-first timeline (plus `status` + relative recency on cards/detail). Point `home.buildingCollection` at it for the home feed. See the Building section recipe above.

## Guardrails

- **Existing posts have published URLs.** If the user has `/posts/<slug>/` URLs that have been shared, do not change the route or add a route prefix. Stick with `route: "/posts"` for the posts collection.
- **`baseURL` matters.** For GitHub Pages on a custom domain, use `https://yourdomain.com/`. For project pages, include the repo path: `https://USER.github.io/REPO/`. Inkwell uses `baseURL` to resolve `/assets/...` prefixes and canonical URLs.
- **Don't overload `home`.** It's optional. If you don't set it, `/` falls back to the legacy paginated landing (when there are no `collections`) or doesn't get emitted (when there are `collections`). The simpler the home, the better the long-term experience.
- **Custom layout names need theme support.** If you set `detailTemplate: "layouts/my-custom"`, that template must exist in `themes/<theme>/templates/layouts/my-custom.html` (project-side) or be one of the bundled theme's layouts.

## Brand mark (top-bar) options

The `quiet` theme renders a 28×28 brand mark to the left of the site name. Two options:

1. **Auto-derived text initial.** The default. Inkwell uses the first letter of `author.name` (or `title`) inside a colored pill. Zero config.
2. **Image mark via `brandIcon`** (v0.8.0+). Set `brandIcon.light` (and optionally `brandIcon.dark`) to image URLs and inkwell injects them as `:root { --brand-icon-light: url(…); --brand-icon-dark: url(…); }` for the bundled `.top-brand-mark-icon` rule. The dark variant swaps in via the manual theme toggle. No template or CSS override needed.

```jsonc
{
  "brandIcon": {
    "light": "/assets/icons/kb.png",
    "dark":  "/assets/icons/kb-dark.png"   // optional; reuses light when unset
  }
}
```

Aim for ≥120×120 source images so they look crisp at any DPR. PNGs with transparency work; JPEGs are fine if the icon already has its own background.

## Analytics (Umami)

Inkwell ships a first-class Umami integration. Add an `analytics.umami` block to `blog.config.json`:

```jsonc
{
  "analytics": {
    "umami": {
      "scriptUrl": "https://analytics.example.com/script.js",
      "websiteId": "<prod website ID>",
      "domains": "example.com",
      "respectDoNotTrack": true,
      "local": {
        "scriptUrl": "http://localhost:3000/script.js",
        "websiteId": "<dev website ID>",
        "domains": "localhost"
      }
    }
  }
}
```

Production builds (`inkwell build`) inject the prod script with the configured `data-*` attributes. `inkwell serve --watch` swaps in the `local` block when present and emits no script at all when it's absent — so dev sessions never accidentally ping the prod Umami instance. Set `domains` to the production hostname so any non-prod traffic that does pick up the prod script gets filtered server-side. Other providers (Plausible, Fathom, custom embeds) don't have first-class config; route them through the `head` HTML fragment via `theme-customize`'s "inject a script" recipe.

## Hand-Offs

- For **résumé / experience data**, hand off to `portfolio-data`.
- For **drafting prose** (case study or post body), hand off to `blog-writing`.
- For **customizing a theme template/asset** (e.g. tweaking the top-bar layout), hand off to `theme-customize`.
- For **deploying** to GitHub Pages, run `inkwell deploy setup github-pages` then commit + push.

## Multi-language sites (v0.5+)

If the user wants the site available in more than one language, add an `i18n` block to `blog.config.json`:

```jsonc
{
  "i18n": { "defaultLanguage": "en", "languages": ["en", "ja"] },
  // ...site-level fields in the default language...
  "translations": {
    "ja": {
      "tagline": "...",
      "heroHeadline": "...",
      "footerCta": { "headline": "..." },
      "themeCopy": { "workCardCta": "..." },   // partial overlay — unset fields fall back to defaults
      "nav":   [{ "label": "...", "route": "/work/" }],
      "home":  { "featuredLabel": "...", "recentLabel": "..." },
      "author": { "tagline": "...", "heroSummary": "..." },
      "collections": [{ "id": "posts", "headline": "..." }]
    }
  }
}
```

URL shape: default language at canonical root (`/posts/foo/`), other languages prefixed (`/ja/posts/foo/`). `/<defaultLang>/...` aliases redirect to canonical. Don't change existing routes for the default language.

Authoring conventions:

- Translate a post: add `foo.ja.md` next to `foo.md`. Same `slug` in front matter pairs them.
- Translate a page: add `about.ja.md` next to `about.md`.
- Translate a data file: add `resume.ja.yml` next to `resume.yml`.
- Untranslated items still appear on the JA listing pages (with default-language content as fallback) — you don't have to translate everything up front.

Hand off to `portfolio-data` for translated `data/<file>.<lang>.yml`, to `blog-writing` for translated post/project bodies, and to `theme-customize` for adding new translatable theme strings.
