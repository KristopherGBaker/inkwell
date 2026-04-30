# `inkwell serve`

Starts a local preview for the generated output, optionally with file watch + live reload.

## Usage

```bash
inkwell serve
inkwell serve --port 9000
inkwell serve --watch              # rebuild + live-reload on file changes
```

## Watch Mode

`--watch` rebuilds when you edit:
- `content/**/*.md` (posts, collection items, pages)
- `data/**`
- `themes/<name>/**` (overridden templates/assets)
- `blog.config.json`
- `public/**`, `static/**`

Browsers connected to the preview auto-refresh after a successful rebuild.

## Prerequisite

Without `--watch`, you must have run `inkwell build` first so `docs/` (or your configured `outputDir`) exists. With `--watch`, the server triggers a build before serving.

## Expected Output

```
Preview available at http://localhost:<port> (serving <path>)
```

## Common Issues

- **Port in use.** Pick a different port with `--port`.
- **Watch missing changes.** Make sure you're editing files inside the project root; the watcher excludes `.build`, `node_modules`, and the configured `outputDir`.
