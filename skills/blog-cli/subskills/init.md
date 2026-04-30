# `inkwell init`

Initialize a new inkwell project in the current directory.

## What It Creates

- `blog.config.json` — minimal config: title, baseURL, theme (`default`), outputDir.
- `content/posts/` — where your posts will live.
- `themes/default/` — minimal scaffold (`theme.json` + a stub `templates/layout.html`). The actual runtime templates ship bundled inside the inkwell binary; this directory is only needed if you want to override individual templates per file.
- `public/` — files copied verbatim into the build output.

## Usage

```bash
inkwell init
```

`init` operates on the current working directory. To scaffold elsewhere, `cd` there first.

## Verify

```bash
test -f blog.config.json
test -d content/posts
test -f themes/default/theme.json
```

## Next Steps

For a **blog**, run `inkwell post new "Hello World"`.

For a **portfolio site**, edit `blog.config.json` to add:
- `theme: "quiet"` to switch to the bundled portfolio theme.
- An `author` block with name/role/social links.
- A `nav` array for the top bar.
- A `home` block with `featuredCollection` + `recentCollection`.
- A `collections` array declaring `posts`, `projects`, etc.

The `site-setup` skill walks through this interactively.
