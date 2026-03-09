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
- `inkwell check` covers front matter/schema validation, broken internal links, malformed config, missing local `coverImage` files, and taxonomy slug collisions.
