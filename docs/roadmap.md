# Roadmap

## Authoring Workflow

- Preview while writing with `inkwell serve --watch`; it rebuilds on content, theme, config, and public asset changes, then reloads the browser.
- Publish an archive at `/archive/`; it is linked from the home page, ordered newest first, and excludes drafts.
- Ship default SEO metadata from `baseURL` and the generated route set; add `canonicalUrl` in post front matter when a post should point at a different canonical URL.
- Run `inkwell check` before publishing to catch schema/front matter issues, broken internal links, malformed config, missing local cover images, and taxonomy slug collisions.
