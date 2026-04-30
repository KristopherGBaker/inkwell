# `inkwell post new`

Create a markdown post with default front matter in `content/posts/`.

## Usage

```bash
inkwell post new "Hello World"
```

## Behavior

- Slugifies the title (`hello-world`).
- Creates `content/posts/YYYY-MM-DD-hello-world.md`.
- Seeds front matter with `title`, `date` (ISO 8601 now), `slug`, `draft: true`.
- Body starts with the placeholder `Start writing here.`.

## Publishing

The new post is a draft. Edit it, then either:
- Flip the front matter manually: `draft: false`.
- Or run `inkwell post publish hello-world`.

Drafts do not appear in builds, sitemap, RSS, or search index.

## Other Collections

For non-post collections (e.g. `projects`), use `inkwell content new <collection> "<title>"` instead. `post new` is a thin alias that's only wired up for the legacy `posts` collection. See `subskills/content-new.md`.

## Next Step

`inkwell build` after editing post content, or `inkwell serve --watch` for a live-reload preview.
