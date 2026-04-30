# `inkwell theme`

Manage available themes and the active theme selection.

## Usage

```bash
inkwell theme list
inkwell theme use default
inkwell theme use quiet
```

## Bundled Themes (v0.3+)

| Theme | Use case | Look |
|-------|----------|------|
| `default` | Blog | Tailwind, amber/stone palette, search, paginated landing, archive page |
| `quiet` | Portfolio (or blog + portfolio) | Fraunces / Manrope / JetBrains Mono, generous whitespace, print-friendly résumé layout |

Both themes ship inside the inkwell binary as bundled resources, so you don't need to copy them into your project.

## Behavior

- `theme list` prints the theme directories present in `projectRoot/themes/`. **It does not list bundled themes.** If your project has no `themes/` directory, the list is empty even though `default` and `quiet` are available.
- `theme use <name>` updates the `theme` field in `blog.config.json`. It validates that a project-side `themes/<name>/` directory exists OR (in v0.3+) that the name matches a bundled theme.

## Customizing a Theme

You don't need to copy the entire theme to override one template or asset. Drop a single file into `themes/<theme>/templates/<path>` or `themes/<theme>/assets/<path>` in your project; the renderer prefers project-side files file-by-file and falls back to the bundled originals for everything else.

See the `theme-customize` skill for a step-by-step walkthrough.

## Failure Mode

`theme use` fails when neither a project-side `themes/<name>/` nor a bundled theme matches the requested name.
