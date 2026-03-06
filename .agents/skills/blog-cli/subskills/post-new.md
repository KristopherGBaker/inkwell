# `blog post new`

Create a markdown post with front matter defaults.

## Usage
```bash
blog post new "Hello World"
```

## Behavior
- Slugifies title (`hello-world`).
- Creates `content/posts/YYYY-MM-DD-hello-world.md`.
- Seeds front matter with `title`, `date` (ISO8601), `slug`, `draft: true`.

## Next Step
Run `blog build` after editing post content.
