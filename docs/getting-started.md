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
