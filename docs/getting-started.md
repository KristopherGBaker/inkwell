# Getting Started

1. Initialize a new blog project.
2. Create a markdown post with front matter.
3. Preview locally with rebuilds on save.
4. Build to `docs/`.
5. Run checks before deploy.

```bash
swift run inkwell init
swift run inkwell post new "My First Post"
swift run inkwell serve --watch
swift run inkwell build
swift run inkwell check
```

- `serve --watch` rebuilds when you edit posts, theme files, `blog.config.json`, or files in `public/`, and refreshes the preview automatically.
- The generated site includes an `/archive/` page linked from the home page; it shows published posts newest first and omits drafts.
- Canonical URLs and `og:url` default to `baseURL + route`; set `canonicalUrl` in post front matter to override the canonical URL for a post.
- `inkwell check` covers front matter/schema validation, broken internal links, malformed config, missing local asset files (`coverImage`, `shots`, `featuredImage`), and taxonomy slug collisions.

## Beyond Posts (v0.3+)

### Multiple collections

Add a `collections` array to `blog.config.json` to define content types beyond posts:

```json
{
  "collections": [
    { "id": "posts", "dir": "content/posts", "route": "/posts" },
    { "id": "projects", "dir": "content/projects", "route": "/work", "sortBy": "year", "taxonomies": ["tags"] }
  ]
}
```

Each collection produces a list page at `<route>/`, detail pages at `<route>/<slug>/`, and per-taxonomy archives at `<route>/<taxonomy>/<slug>/`. Scaffold new items with `inkwell content new <id> "Title"`.

### Standalone pages

Drop markdown files into `content/pages/`. Routes derive from path: `about.md → /about/`, `now/index.md → /now/`. Front-matter `layout: <name>` selects the theme template (default `page`).

### Data files

Put YAML/JSON in `data/`. Each file is loaded into the template context as `data.<basename>`. For example, `data/experience.yml` is available as `data.experience`. Use this for résumé content, link rolls, or any structured data the templates render.

### Themes

Set `theme: "quiet"` in `blog.config.json` to use the bundled portfolio-friendly theme. Override individual templates by dropping files into `themes/<name>/templates/`; they shadow the bundled theme on a per-file basis.

### Site identity, nav, and home

Add an `author` block, a `nav` array, and a `home` block to drive the top bar, footer, and landing page. See the RFC `docs/rfcs/2026-04-30-content-collections-and-templating.md` for the full schema.

### Authoring résumé data

The `portfolio-data` skill walks Claude Code (or any compatible agent) through importing résumé content into `data/experience.yml`, `data/competencies.yml`, and `data/education.yml`. Run `/portfolio-data` to start.

### Analytics (Umami)

Inkwell can inject a [Umami](https://umami.is) tracking script for you. Add an `analytics.umami` block to `blog.config.json`:

```jsonc
{
  "analytics": {
    "umami": {
      "scriptUrl": "https://analytics.example.com/script.js",
      "websiteId": "<your website ID>",
      "domains": "example.com",       // optional — restrict events to your prod hostname
      "respectDoNotTrack": true,      // optional — honor the browser's DNT header
      "hostUrl": "https://analytics.example.com",  // optional — Umami API host if different from script src
      "tag": "site",                  // optional — segments events by tag in the dashboard

      "local": {                      // optional override applied during `inkwell serve --watch`
        "scriptUrl": "http://localhost:3000/script.js",
        "websiteId": "<dev website ID>",
        "domains": "localhost"
      }
    }
  }
}
```

Production builds (`inkwell build`) always use the top-level fields. `inkwell serve --watch` swaps in the `local` block if set, and emits no script tag at all when it isn't — so dev sessions never accidentally ping your prod Umami instance. Set `domains` to your production hostname so any stray non-prod traffic that does load the prod script gets filtered server-side. Required fields are `scriptUrl` and `websiteId`; everything else is optional.

#### Event tracking

By default the integration records page views only. Add an optional `events` block to track clicks, outbound links, and downloads on top of page views. Everything is off unless you turn it on, so existing sites are unaffected.

```jsonc
{
  "analytics": {
    "umami": {
      "scriptUrl": "https://analytics.example.com/script.js",
      "websiteId": "<your website ID>",
      "events": {
        "outboundLinks": true,    // track clicks to other domains as `outbound-link`
        "downloads": true,        // track file downloads as `download`
        "themeElements": true,    // tag the theme's known CTAs (see table below)
        "downloadExtensions": ["pdf", "zip", "dmg"]  // optional — override the default list
      }
    }
  }
}
```

`outboundLinks` and `downloads` install one tiny inline click listener that fires `umami.track()` for any matching link **anywhere on the page**, including links inside post and case-study bodies. A link counts as a download when it has a `download` attribute or its path ends in one of `downloadExtensions` (default: `pdf, zip, dmg, csv, xlsx, doc, docx, pptx, mp3, mp4, png, jpg, svg`). Downloads take precedence over outbound links, so each click fires at most one event.

`themeElements` emits declarative `data-umami-event` attributes on the bundled `quiet` theme's conversion CTAs:

| Element | Event name | Properties |
|---|---|---|
| Résumé PDF download | `resume-download` | — |
| Résumé print button (no PDF) | `resume-print` | — |
| Email links (footer / about / résumé / post reply) | `email` | — |
| Social links (footer / résumé) | `social` | `network` (the link label, e.g. `GitHub`) |
| Landing hero primary / secondary CTA | `cta-hero-primary` / `cta-hero-secondary` | — |

Like the script tag itself, event tracking honors build mode: it only renders when the effective Umami block is active, so `inkwell serve --watch` without a `local` block emits no tracker and no event attributes. To exercise events locally, add an `events` block inside `local` too — `local` inherits nothing from the prod block.
