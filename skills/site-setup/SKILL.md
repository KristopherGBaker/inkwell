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
    "email": "kris@example.com",
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
  "scaffold":        null                 // optional path to a custom scaffold template (future)
}
```

## Guardrails

- **Existing posts have published URLs.** If the user has `/posts/<slug>/` URLs that have been shared, do not change the route or add a route prefix. Stick with `route: "/posts"` for the posts collection.
- **`baseURL` matters.** For GitHub Pages on a custom domain, use `https://yourdomain.com/`. For project pages, include the repo path: `https://USER.github.io/REPO/`. Inkwell uses `baseURL` to resolve `/assets/...` prefixes and canonical URLs.
- **Don't overload `home`.** It's optional. If you don't set it, `/` falls back to the legacy paginated landing (when there are no `collections`) or doesn't get emitted (when there are `collections`). The simpler the home, the better the long-term experience.
- **Custom layout names need theme support.** If you set `detailTemplate: "layouts/my-custom"`, that template must exist in `themes/<theme>/templates/layouts/my-custom.html` (project-side) or be one of the bundled theme's layouts.

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
