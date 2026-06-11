# Feeds

Every build emits three feed formats for the blog, no configuration required:

- **RSS 2.0** — `/rss.xml`
- **Atom 1.0** — `/atom.xml`
- **JSON Feed 1.1** — `/feed.json`

Each carries the 20 most recent non-draft entries with the full rendered post body (`content:encoded` in RSS, `content type="html"` in Atom, `content_html` in JSON Feed). Root-relative URLs inside the body are absolutized so readers can resolve images and links. Dates are emitted in each format's required shape (RFC-822 for RSS, RFC-3339 for Atom/JSON Feed). All bundled themes advertise the feeds with `<link rel="alternate">` autodiscovery tags in `<head>`.

The feed source is the `posts` collection if present, otherwise the first declared collection. Sites with no collections fall back to a single feed built from `content/posts/`.

## Multi-language feeds

With i18n enabled, each language gets its own set (`/rss.xml` + `/<lang>/rss.xml`, and likewise for Atom and JSON Feed). A language feed contains only that language's entries — no fallback — so subscribers get a consistent language. The channel title and description come from `title` / `description` in `blog.config.json`, localized through the `translations.<lang>` overlay:

```json
{
  "title": "Kris",
  "description": "Notes from Tokyo.",
  "translations": { "ja": { "description": "東京からのノート。" } }
}
```

## Per-collection and combined feeds

Add a `feeds` block to opt into a feed per collection plus a combined "everything" feed:

```json
{
  "feeds": {
    "combined": true,
    "collections": ["posts", "projects", "updates"]
  }
}
```

- Each id in `collections` gets its own feed under that collection's route — e.g. `posts` → `/posts/rss.xml`, a `projects` collection routed at `/work` → `/work/rss.xml` (plus `atom.xml`, `feed.json`, and `/<lang>/...`).
- A **child collection** (e.g. `updates`, the "what I'm building" timeline) feeds at its own route with each item linked under its parent project (`/building/<project>/<slug>/`).
- Items date by their `date` field; a collection that dates by `year` (like work case studies) falls back to January 1 of that year, so a feed without per-item dates still sorts and renders.
- When `combined` is true (the default once a `feeds` block is present), the site root `/rss.xml` (+ atom/json, + `/<lang>/`) becomes the merged feed across all listed collections, newest-first. The per-collection feeds carry that collection's items only.
- `limit` (default 20) caps items per feed.
- Each collection feed is advertised site-wide with its own `<link rel="alternate">` autodiscovery tag, titled `"<site title> · <collection>"`.

Without a `feeds` block, behavior is unchanged: a single feed at the root from the primary blog collection.
