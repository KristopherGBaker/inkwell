# Inkwell — agent guide

Swift static publishing tool. Started as a blog generator; v0.3 adds generic content collections, standalone pages, data files, and a second theme so it can drive a portfolio site.

## Quick commands

| Task | Command |
|------|---------|
| Build CLI | `swift build` |
| Run all tests + lint | `make verify` |
| Run a single test target | `swift test --filter <ClassName>` |
| Run inkwell against a fixture | `swift run inkwell <subcommand>` from the project root, or invoke `.build/debug/inkwell` from inside any target project |
| Bump version | `python3 scripts/bump_version.py <X.Y.Z>` (or `--part {major,minor,patch}`) |
| Build CSS for default theme | `npm run build:tailwind` |
| Install npm deps (needed for shiki syntax highlighting at test time) | `npm ci` |

`make verify` requires SwiftLint on PATH; the Makefile defaults `SWIFTLINT` to a Mint-managed pin, override with `SWIFTLINT=swiftlint make verify` when running locally.

## Architecture (v0.3)

Modules under `Sources/`:

- **BlogCLI** — ArgumentParser commands. Subcommands: `init`, `post new|list|publish`, `content new`, `build`, `serve`, `check`, `theme`, `plugin`, `deploy`.
- **BlogCore** — content loading, routing, build pipeline, validation.
  - `Content/ContentLoader.swift` — `loadPosts`, `loadCollections`, `loadPages`, plus the shared front-matter splitter.
  - `Content/DataLoader.swift` — reads `data/*.yml|json` into `[String: Any]`.
  - `Models/SiteConfig.swift` + `AuthorConfig`, `CollectionConfig`, `HomeConfig`, `NavConfig` — config schema.
  - `Models/CollectionItem.swift`, `PostFrontMatter.swift`, `PostDocument.swift`, `Page.swift` — content models.
  - `Routing/PageContextBuilder.swift` — turns content into `(route, template, context)` plans. Branches between legacy posts mode (no `collections` in config) and explicit-collections mode.
  - `BuildPipeline.swift` — orchestrates load → render markdown → build plans → render templates → write output.
  - `Validation/ProjectChecker.swift` — front-matter, asset paths, broken links.
- **BlogRenderer** — Markdown → HTML via `cmark`, with shiki shell-out for syntax highlighting.
- **BlogThemes** — `TemplateRenderer.swift` (Stencil) and `ThemeManager.swift` (head-asset injection, asset copying). Default and quiet themes ship bundled as SPM resources from `Sources/BlogThemes/Resources/themes/`.
- **BlogPlugins** — plugin lifecycle hooks (`beforeParse`, `afterParse`, `beforeRender`, `afterRender`, `onBuildComplete`).
- **BlogPreview** — Vapor-based dev server with watch + live reload.

### Templating

Themes own their HTML. The renderer resolves templates in order:
1. Project-side: `<projectRoot>/themes/<theme>/templates/{,layouts/,partials/}`
2. Bundled: `Sources/BlogThemes/Resources/themes/<theme>/templates/{,layouts/,partials/}`

Project-side files shadow bundled ones file-by-file, so users can customize one template without copying the whole theme.

Stencil syntax notes:
- No autoescape. The `escape` filter is registered; `PageContextBuilder` pre-escapes context values so templates use `{{ value }}` verbatim.
- Use `{% extends "base.html" %}` + `{% block main %}` for layouts; `{% include "<name>.html" %}` for partials.
- Boolean truthiness handles nil gracefully; missing dict keys are falsy.

### Content models

- **Posts** (legacy/blog): typed `PostFrontMatter`. Loaded by `loadPosts(in:)`.
- **Collections** (v0.3): generic `CollectionItem` with typed post fields plus a raw front-matter dictionary for collection-specific extras (`year`, `metrics`, `shots`, etc.). Loaded by `loadCollections(_:in:)`.
- **Pages** (v0.3): `content/pages/*.md`, route from path, `layout` selects the theme template.
- **Data files** (v0.3): `data/*.yml|json` → `data.<basename>` in every template context.

### Themes

- `default` — original blog theme. Tailwind + amber/stone palette. Used when `siteConfig.theme` is omitted or `"default"`.
- `quiet` — portfolio-friendly theme bundled in v0.3. CSS tokens + components, no Tailwind. Layouts: `landing`, `post`, `page`, `post-list`, `work-list`, `case-study`, `resume`, `taxonomy`, `404`.

`ThemeManager.injectHeadAssets` branches per theme: default injects Tailwind/Prism/Mermaid; quiet injects tokens.css/components.css/print.css/theme-toggle.js.

## Conventions

- **Commits:** Conventional Commits, lowercase scopes (`feat(themes):`, `fix(content):`, etc.). The `kb-commit` skill groups working-tree changes into semantic commits automatically.
- **Tests:** TDD via the `superpowers:executing-plans` workflow — write the failing test, watch it fail, write the minimal implementation, watch it pass.
- **Plans + RFCs:** `docs/plans/` for executable implementation plans, `docs/rfcs/` for design decisions. Latest: `2026-04-30-content-collections-and-templating.md` (RFC), `2026-04-30-v0-3-implementation-plan.md` (plan).
- **Skills:** Agent skills live in `skills/`. Currently shipped: `blog-cli` (CLI command routing), `blog-writing` (post authoring), `portfolio-data` (résumé import to `data/*.yml`).

## Things that look weird but aren't

- `themes/default/` at the repo root coexists with `Sources/BlogThemes/Resources/themes/default/`. The repo-root copy is the v0.2 reference scaffold (still scaffolded by `inkwell init`); the bundled copy under `Sources/` is what the runtime actually loads. They're kept in sync via the bump script.
- The legacy posts code path (when `siteConfig.collections` is absent) emits top-level `/tags/<slug>/` URLs and `/archive/`; the new collections path emits `<route>/tags/<slug>/` and no `/archive/`. This preserves v0.2 sites verbatim while letting new portfolio configs scope taxonomies under their collection.
- `content/pages/resume.md` is intentionally a one-line shell with empty body — the `resume` layout reads from `data/experience.yml`, `data/competencies.yml`, `data/education.yml` and ignores `page.content`. The front-matter splitter tolerates empty bodies.
- `make verify` requires `npm ci` to have run at least once: shiki-based syntax highlighting in `GFMEngineTests` shells out to `node scripts/highlight-code.mjs`, which needs `node_modules/`.

## How to extend

- **Add a new collection** to a project: edit `blog.config.json`, add `{id, dir, route}` under `collections`, then `inkwell content new <id> "<title>"`.
- **Add a new theme:** create `Sources/BlogThemes/Resources/themes/<name>/{theme.json,templates/,assets/}`. Add a head-injection branch in `ThemeManager.injectHeadAssets` if the theme needs different `<head>` content. Bump version via the bump script.
- **Add a new field type to `inkwell check`'s asset validation:** extend `ProjectChecker.assetFieldNames`.

## Reference docs

- `docs/rfcs/2026-04-30-content-collections-and-templating.md` — v0.3 design source of truth
- `docs/plans/2026-04-30-v0-3-implementation-plan.md` — TDD-driven implementation plan
- `docs/roadmap.md` — what's shipped vs. deferred
- `docs/getting-started.md` — user-facing quick start
