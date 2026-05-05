# Image Pipeline & Content Polish Implementation Plan

**RFC:** `docs/rfcs/2026-05-05-image-pipeline-and-content-polish.md`
**Date:** 2026-05-05
**Target:** v0.6 (image pipeline + OG cards) → v0.7 (polish bundle)

Test-driven where practical. Each phase ends with a green build, at least one new test, and is shippable as a standalone PR. Phases 1–4 ship as v0.6; phases 5–8 ship as v0.7. The split is for release notes, not branching — phases share infrastructure (Node shellout, cache directory) so the same branch can carry both if convenient.

## Conventions

- New Node scripts live under `scripts/` and follow the shiki pattern (base64-encoded args, silent failure with empty stdout).
- New build artifacts go through `OutputWriter`; cache lives at `<projectRoot>/.inkwell-cache/{images,og}/` and is created on demand.
- All new public types `Codable, Equatable` where they round-trip config.
- Tests live alongside their target (`Tests/BlogCoreTests/...`, `Tests/BlogRendererTests/...`).
- Each phase ends with a SwiftLint-clean diff; expect to add `// swiftlint:disable` only where unavoidable and justify in the commit body.
- Ship one PR per phase. Squash-merge to keep the v0.6 / v0.7 release notes coherent.

---

## v0.6 — Image Pipeline + OG Cards

### Phase 1 — Cache + Node shellout scaffolding

Goal: shared infrastructure phases 2–4 build on. No user-visible change.

- [ ] `Sources/BlogCore/Cache/BuildCache.swift` — wraps `<projectRoot>/.inkwell-cache/`; `path(for category: String, key: String, ext: String)`, `exists(...)`, `write(...)`, atomic temp+rename.
- [ ] `Sources/BlogCore/Tools/NodeRunner.swift` — extract the shiki shellout pattern into a reusable helper (`run(script:, args:) -> Data?`). `GFMEngine.highlightWithShiki` migrates to use it (no behavior change).
- [ ] `inkwell init` adds `.inkwell-cache/` to the scaffolded `.gitignore`.
- [ ] Tests: cache hits short-circuit; cache misses write atomically; corrupted cache files are detected and re-rendered (size-zero check).

### Phase 2 — Image variant generation

Goal: source images under `static/` get cached resized variants on build.

- [ ] `Sources/BlogCore/Images/ImageVariantGenerator.swift` — given a source path + variant params, ensures cached outputs exist. Shells out to `scripts/process-image.mjs`.
- [ ] `scripts/process-image.mjs` — reads source path + JSON variant spec; outputs file paths to stdout; uses `sharp` for resize + format conversion.
- [ ] Variant spec defaults: widths `[480, 800, 1200, 1600]`, formats `[avif, webp]` plus passthrough source format. Cap variant width at intrinsic source width.
- [ ] Bypass: SVG, animated GIF (probe via `sharp.metadata`), files < 32 KB.
- [ ] `package.json` gains `sharp` as devDependency.
- [ ] Tests: small JPEG generates 4 widths × 2 formats; SVG bypassed; second build is cache-hit (no node spawn); intrinsic 600px source caps variant set at 480 + 600.

### Phase 3 — `<picture>` rewrite pass

Goal: rendered HTML `<img>` becomes `<picture>` with srcset. Front-matter image fields resolved to the same shape.

- [ ] `Sources/BlogCore/Images/PictureRewriter.swift` — post-render pass over rendered HTML. For each `<img src=...>` resolving to a project asset, replaces with `<picture>` block referencing variants. Preserves `alt`, applies `loading="lazy" decoding="async"` and intrinsic `width` / `height` for CLS.
- [ ] `BuildPipeline` invokes the rewriter after `AssetURLRewriter` and before theme head injection.
- [ ] Front-matter image resolution: `PageContextBuilder` resolves `coverImage`, `shots[].image`, and any field listed in the (renamed) `ProjectChecker.assetFieldNames` into a `ResponsiveImage` value (`{src, srcset, srcsetAvif, sizes, width, height, alt}`). Themes can render `{{ post.coverImage.srcset }}` or `{% include "responsive-image.html" with image=post.coverImage %}`.
- [ ] Default + quiet themes get a `partials/responsive-image.html` that renders the `<picture>` block.
- [ ] Tests: a markdown body with `![alt](/static/foo.jpg)` produces `<picture>` with three `<source>` elements. Front-matter `coverImage: /static/cover.png` resolves to a `ResponsiveImage` exposed in the post context. Bypass paths still get width/height. Asset under `static/raw/` skips processing entirely.

### Phase 4 — OG card generation

Goal: every page has an `og:image` PNG generated at build time.

- [ ] `Sources/BlogCore/OG/OGCardGenerator.swift` — for each emitted page plan, computes a cache key (theme + title + author + lang) and ensures `<outputDir>/og/<route-hash>.png` exists.
- [ ] `scripts/render-og.mjs` — reads JSON spec from stdin (title, subtitle, accent, font URL); uses `satori` + `@resvg/resvg-js`; writes PNG to specified path.
- [ ] Theme contract: each theme ships `og/template.json` (HTML/JSX-style structure consumable by satori, plus default font + accent). Inkwell falls back to a built-in template if the theme is missing one.
- [ ] `<head>` injection: `og:image` and `twitter:image` meta tags reference the generated card. Front-matter `ogImage:` overrides; absolute external URLs pass through unchanged.
- [ ] i18n: one card per language, keyed on translated title.
- [ ] `package.json` gains `satori` + `@resvg/resvg-js` devDependencies.
- [ ] Tests: a post with title "Hello" generates `docs/og/<slug>.png` (>0 bytes, decodes as PNG). Front-matter `ogImage:` overrides. i18n project emits one card per language. Cache-hit on second build.

### Release: v0.6.0

After phase 4 lands cleanly, bump version. Release notes: image pipeline + OG cards. Test against krisbaker.com, replacing hand-prepped Wolt screenshots with raw exports.

---

## v0.7 — Content Polish Bundle

### Phase 5 — Reading time

Goal: posts and case-studies expose `readingTime` to templates.

- [ ] `Sources/BlogCore/Routing/ReadingTime.swift` — `ReadingTime.compute(html:) -> Int` (minutes, 200 WPM, ceil). Strips tags and entities before counting.
- [ ] `PageContextBuilder` populates `post.readingTime` and `post.readingTimeLabel` for every renderable post / collection item with body content.
- [ ] `themeCopy.readingTimeLabel` (default `"%d min read"`) — translatable per the existing i18n overlay model.
- [ ] Default theme `post.html` and quiet theme `post.html` + `case-study.html` show the label.
- [ ] Tests: 800-word body → 4 min. Empty body → 0 min (label suppressed). i18n overlay translates the label.

### Phase 6 — Table of contents

Goal: opt-in TOC for long-form pages.

- [ ] `Sources/BlogCore/Routing/HeadingExtractor.swift` — pre-render pass over HTML body. Adds `id="<slug>"` to every `<h2>` / `<h3>`, deduplicates collisions with `-2`, `-3`, returns `[(level, text, anchor)]`.
- [ ] `PageContextBuilder` exposes `page.toc` for posts/collection items where (a) front-matter `toc: true`, OR (b) `>= 3` h2s (auto-trigger threshold; tunable via `siteConfig.tocAutoThreshold` later if needed).
- [ ] Themes ship `partials/toc.html`. Quiet `case-study.html` and `post.html` include it conditionally.
- [ ] Tests: H2-heavy post auto-gets TOC; short post does not; explicit `toc: true` overrides; duplicate headings get unique anchors; nested h3 nests under preceding h2.

### Phase 7 — Code-copy buttons

Goal: every code block ships a copy button.

- [ ] Both themes' assets gain `assets/js/code-copy.js` (one-shot DOM enhancer; finds `<pre>` blocks, injects a button, wires `navigator.clipboard.writeText`).
- [ ] CSS additions to default + quiet stylesheets for button placement and feedback states (idle / copied / error).
- [ ] `ThemeManager.injectHeadAssets` adds the script tag for both themes.
- [ ] No Swift logic; purely theme work.
- [ ] Tests: snapshot test asserting the script tag is injected for both themes (unit-level). Manual verification only for clipboard interaction.

### Phase 8 — KaTeX math

Goal: `$inline$` and `$$block$$` math renders server-side.

- [ ] `Sources/BlogRenderer/Engines/MathEngine.swift` — pre-pass over markdown body. Detects math runs, replaces with placeholders, calls `scripts/render-math.mjs`, restitches results.
- [ ] Detection rules per RFC: inline `$x$` requires non-whitespace adjacency on both sides; block `$$...$$` must occupy its own line.
- [ ] `scripts/render-math.mjs` — Node + `katex`; renders to HTML.
- [ ] `PostDocument` / `CollectionItem` gain a `hasMath: Bool` flag (computed during render). `PageContextBuilder` propagates it.
- [ ] `ThemeManager.injectHeadAssets` includes KaTeX CSS only when `page.hasMath` (from any plan in the build); CSS pinned to a vendored copy in theme assets to avoid runtime CDN.
- [ ] `package.json` gains `katex` devDependency.
- [ ] Tests: post with `$E = mc^2$` renders `<span class="math math-inline">`; post without math has no KaTeX CSS injected; `$5 and $10` does NOT trigger math rendering (false-positive guard).

### Release: v0.7.0

After phase 8 lands cleanly, bump version. Release notes: content polish bundle.

---

## Sequencing notes

- Phases 1 and 2 must land in order; phases 3 and 4 can be parallel.
- Phases 5–8 are independent; ship in any order.
- Phase 7 (code-copy) is the lowest-risk warm-up if a contributor wants a single-PR contribution.
- Phase 4 (OG cards) is the most opinionated; expect a follow-up tuning PR for typography.
- Document the new Node prerequisite in the README under "Prerequisites" before v0.6.0 ships.
