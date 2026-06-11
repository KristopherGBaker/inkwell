# CLI reference

| Command | What it does |
|---------|--------------|
| `inkwell init` | Scaffold a new project in the current directory |
| `inkwell post new "<title>"` | Create a new draft post in `content/posts/` |
| `inkwell post list` | List posts and their state |
| `inkwell post publish <slug>` | Flip a post from `draft: true` to `false` |
| `inkwell content new <collection> "<title>"` | Scaffold a new item in any declared collection |
| `inkwell build` | Build the site to `outputDir` (default `docs/`) |
| `inkwell serve [--watch]` | Local dev server with optional rebuild + live reload |
| `inkwell check` | Validate front matter, asset paths, links, taxonomy collisions |
| `inkwell theme use <name>` | Switch the active theme in `blog.config.json` |
| `inkwell deploy setup github-pages` | Generate the GitHub Pages workflow |

## Notes

- `serve --watch` rebuilds when you edit content, theme files, `blog.config.json`, or anything in `public/` and `static/`, and live-reloads the browser.
- `inkwell check` covers front matter/schema validation, broken internal links, malformed config, missing local asset files (`coverImage`, `shots`, `featuredImage`, `ogImage`, `thumbnail`), taxonomy slug collisions, and child-collection items whose parent slug matches nothing.
- `inkwell content new <childId> "Title"` scaffolds a dated file pre-seeded with the parent-link field when the collection declares a `parent`.

## Deploying to GitHub Pages

```bash
inkwell init
inkwell deploy setup github-pages
```

Review `baseURL` in `blog.config.json` for your Pages URL before publishing. The setup is optional and does not rewrite existing config. Build output is a plain static directory, so any other host works too.
