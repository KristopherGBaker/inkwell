# `inkwell build`

Builds the static site into `outputDir` (default `docs/`).

## Usage

```bash
inkwell build
inkwell build --json
```

## What Gets Built

For a legacy blog (no `collections` in config):
- `docs/index.html` (paginated post list)
- `docs/page/2/index.html` (additional pages if posts > 6)
- `docs/archive/index.html`
- `docs/posts/<slug>/index.html`
- `docs/tags/<slug>/index.html`, `docs/categories/<slug>/index.html`

For a portfolio (with `collections`):
- `docs/<collection.route>/index.html` (list page)
- `docs/<collection.route>/<slug>/index.html` (detail page)
- `docs/<collection.route>/<taxonomy>/<slug>/index.html` (scoped taxonomy)
- `docs/<page.route>/index.html` for each `content/pages/*.md`
- `docs/index.html` rendered via `home.template` if `home` is configured

Plus, in every build:
- `docs/sitemap.xml`, `docs/robots.txt`, `docs/rss.xml`
- `docs/search-index.json`
- `docs/assets/` (theme + project assets, project shadowing bundled)
- Whatever is in `public/` and `static/` copied verbatim

## Common Failure Causes

- Invalid front matter (`title`, `slug` required; `date` for posts; `year` for year-sorted collections)
- Malformed markdown fences
- Stencil template errors (typo in a custom template — error message names the template and line)
- Asset references in front matter that don't resolve (run `inkwell check` first)

## Output Format

Default mode prints `Built N route(s) -> /abs/path/docs`.

`--json` mode emits structured output suitable for piping into other tools.
