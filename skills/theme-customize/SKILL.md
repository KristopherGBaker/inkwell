---
name: theme-customize
description: Use when a user wants to customize the look of their inkwell site — override a single template, tweak CSS, swap fonts, change copy in the top bar/footer, or add a new layout. Walks through inkwell's per-file shadow override model so users don't have to fork the whole theme. Triggers on "tweak my site's header", "change the resume layout", "override one CSS file", "modify the quiet theme".
---

# Theme Customization

Use this skill to help a user customize their inkwell site without forking a whole theme. Inkwell themes ship inside the binary as bundled resources; the project's `themes/<theme>/` directory shadows the bundle on a per-file basis. Override one file, leave the rest alone.

## When To Use

- User wants to tweak the top bar, footer, or any partial.
- User wants to change CSS — fonts, colors, spacing, an animation.
- User wants to add a new layout (e.g. a custom `layouts/about.html` for their about page).
- User wants to inject a script (analytics, comments) site-wide.

If the user wants to *create* a whole new theme, this skill is still the right starting point — they'll just be writing more files.

## Mental Model

```
Project root
├── themes/
│   └── quiet/                           ← project-side overrides (optional)
│       ├── templates/
│       │   └── partials/top-bar.html    ← shadows bundled top-bar.html
│       └── assets/
│           └── css/components.css       ← shadows bundled components.css
└── blog.config.json                      ← theme: "quiet"

Inkwell binary
└── themes/quiet/                         ← bundled originals
    ├── templates/...                     ← used when project doesn't have an override
    └── assets/...                        ← copied to docs/assets/, then overlaid by project
```

The renderer looks up each template name in this order:
1. `projectRoot/themes/<theme>/templates/<name>.html`
2. `projectRoot/themes/<theme>/templates/layouts/<name>.html`
3. `projectRoot/themes/<theme>/templates/partials/<name>.html`
4. Bundled equivalents under `Bundle.module/themes/<theme>/templates/`

Assets work the same way at copy time: bundled files land in `docs/assets/`, then project files overlay them.

## Workflow

1. **Identify what to customize.** Ask the user precisely which template or asset they want to change. "Make the header smaller" → `templates/partials/top-bar.html` and/or `assets/css/components.css`.
2. **Find the bundled original.** It lives under `Sources/BlogThemes/Resources/themes/<theme>/...` in the inkwell repo. If the user is working in their own project, they can find it in their inkwell install, or pull it from the GitHub source.
3. **Copy it into the project.** Mirror the path under `themes/<theme>/...`:
   - Bundled: `Sources/BlogThemes/Resources/themes/quiet/templates/partials/top-bar.html`
   - Project override: `themes/quiet/templates/partials/top-bar.html`
4. **Edit the override.** The original file is the starting point — you don't have to start from scratch.
5. **Build to verify.** `inkwell build && inkwell serve --watch`. The renderer will pick up the project file; the rest of the theme stays bundled.

## Common Recipes

### Change a piece of copy (e.g. footer text)

1. Find the partial: `themes/quiet/templates/partials/footer.html`.
2. Copy it into your project at the same path.
3. Edit the copy.

Stencil syntax to remember:
- `{{ value }}` outputs a value; values from `PageContextBuilder` come pre-escaped.
- `{% if site.author.social %}…{% endif %}` for conditionals.
- `{% for item in site.nav %}{{ item.label }}{% endfor %}` for loops.
- `{% include "<name>.html" %}` to embed a partial; included templates inherit the current loop variable scope.

### Tweak CSS (colors, fonts, spacing)

1. Copy the relevant CSS file into `themes/<theme>/assets/css/<file>.css`. For the `quiet` theme, the layered files are:
   - `tokens.css` — design tokens (fonts, colors, spacing scale, type scale)
   - `components.css` — concrete layout (top bar, hero, cards, sections, résumé)
   - `print.css` — print rules for the résumé page
2. Edit the project copy. The bundled version is no longer used for that file.

For small tweaks, override `tokens.css` and change a CSS custom property:

```css
:root {
  --accent: #6d28d9; /* swap amber for violet */
}
```

For larger restructuring, override `components.css` and edit layout rules.

### Add a new layout

1. Decide a layout name (e.g. `notebook`).
2. Create `themes/<theme>/templates/layouts/notebook.html`. Use `{% extends "base.html" %}` so the new layout reuses the theme's HTML shell, top bar, and footer:

```html
{% extends "base.html" %}
{% block main %}
  <main class="container">
    <h1>{{ page.title }}</h1>
    <article class="prose">{{ page.content }}</article>
  </main>
{% endblock %}
```

3. Reference it from a page or collection:
   - Page: `content/pages/<name>.md` with `layout: notebook` in front matter.
   - Collection: set `detailTemplate: "layouts/notebook"` (or `listTemplate`) on the collection in `blog.config.json`.

### Inject a script site-wide (analytics, comments)

1. Create an HTML fragment in your project, e.g. `head-extras.html`:
   ```html
   <script defer src="https://plausible.io/js/script.js" data-domain="example.com"></script>
   ```
2. Add to `blog.config.json`:
   ```json
   { "head": "head-extras.html" }
   ```
3. Inkwell injects the file's contents before `</head>` on every page.

(For per-page or per-theme `<head>` content, override the theme's `base.html` instead.)

## Stencil Crash Course

The bundled themes use Stencil. The features you'll touch:

| Syntax | Effect |
|--------|--------|
| `{{ var }}` | Output `var`. No autoescape; values from inkwell's context are already escaped. |
| `{{ var \| escape }}` | HTML-escape `var` (use for any string you computed yourself in a template). |
| `{% if x %}…{% else %}…{% endif %}` | Conditional. Truthy: non-nil, non-empty, non-zero. |
| `{% for item in items %}…{% endfor %}` | Iterate. Inside the loop, `item.field` accesses fields. |
| `{% include "name.html" %}` | Render another template inline; inherits the parent context. |
| `{% extends "base.html" %}` + `{% block main %}…{% endblock %}` | Template inheritance. |

Avoid:
- Stencil filter chains beyond `escape` — most tag-based logic should live in `PageContextBuilder` instead.
- Multi-line interpolation that's actually trying to be Swift. If you're tempted, the right fix is usually to add the computed value to the context.

## Guardrails

- **Don't copy the whole theme.** Override only the files you're actually changing. The bundle continues to fill in everything else; if you upgrade inkwell later, you get template improvements automatically for unmodified files.
- **Keep override paths exact.** The shadow lookup is path-based. If the bundle has `templates/partials/footer.html`, your override must be `themes/<theme>/templates/partials/footer.html` — not `templates/footer.html` in some flatter structure.
- **Test with `inkwell serve --watch`.** It reloads when you edit theme files, so you see breakage immediately.
- **Mind context shapes.** Each layout has a known context (see `PageContextBuilder` for the canonical shape). Adding a field to a template that isn't in the context will silently render empty.

## Translatable theme strings (v0.5+)

If a theme template has a hardcoded user-facing string (a label, a button, an aria-label, an empty-state message), it should usually be configurable via `ThemeCopyConfig` so sites can override it globally and translate it per language.

To add a new translatable theme string:

1. Add the field to `Sources/BlogCore/Models/ThemeCopyConfig.swift` (optional `String?`, plus the init parameter).
2. Expose it from `themeCopyContext(for:overlay:)` in `PageContextBuilder.swift` with a sensible default — `escapeHTML(over?.<field> ?? base?.<field> ?? "Default text")`.
3. Reference it in the template: `{{ site.themeCopy.<field> }}`.

In the project's `blog.config.json`, sites override globally via `themeCopy.<field>` and per-language via `translations.<lang>.themeCopy.<field>`. Anything not overridden falls back to the default English string baked into the helper.

For per-page strings driven by content (e.g., section labels on the résumé page), prefer Stencil's `default` filter against `data.<file>.labels.<key>` — `{{ data.resume.labels.summary | default:"Summary" }}` — so translations live in `data/<file>.<lang>.yml` and don't need a Swift schema change.

## Hand-Offs

- For initial site config: `site-setup`.
- For CLI commands: `blog-cli`.
- For prose content: `blog-writing`.
