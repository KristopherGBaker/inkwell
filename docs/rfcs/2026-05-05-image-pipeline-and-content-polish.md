# RFC: Image Pipeline and Content Polish

## Metadata
- **Status**: Proposed
- **Date**: 2026-05-05
- **Author**: Kris
- **Target Version**: v0.6 (image pipeline + OG cards) → v0.7 (polish bundle)
- **Related**:
  - `docs/roadmap.md` items #9 Image Pipeline, "Reading time and table of contents", "Multiple feed formats beyond RSS"
  - Hugo's image pipeline (`hugo.image.process`), Astro's `astro:assets`, Eleventy's `eleventy-img` — prior art for the variant + cache shape

## Summary

Add an automatic image pipeline (resize → variants → cached `<picture>` rewriting), generate Open Graph social cards per page, and ship a small polish bundle (reading time, table of contents, code-copy buttons, KaTeX math) so inkwell sites match the table-stakes feel of mature SSGs without manual asset prep.

## Motivation

Three concrete frictions surfaced while building krisbaker.com:

1. **Manual image sizing.** Every Wolt case study screenshot needed pre-sized exports; a 1320×2856 phone screenshot was dropped in raw and overflowed the layout. The site has no way to declare "use this image, fit it to the column" — authors are responsible for both source assets and dimensions.
2. **No social cards.** Sharing a post produces a generic preview with no image. Modern personal sites expect auto-generated `og:image` for every page so links look intentional in Slack / iMessage / Twitter / Mastodon.
3. **Missing reader affordances.** Long posts have no reading time or TOC. Code blocks have no copy button. Math (KaTeX) doesn't render — a blocker for any technical writing involving formulas. Each is small; together they're what readers notice the moment a static site stops feeling like a static site.

The right response is to add the small set of build-time primitives that solve all three, without becoming a CMS or coupling to one image format. The image pipeline anchors the work; OG cards reuse its output; the polish items are independent quick wins.

## Goals

1. Authors drop in source images (reasonable size) and inkwell handles the rest: variants, format conversion, dimensions, lazy loading, `<picture>` markup.
2. Every page gets an `og:image` automatically. Themes can override the template; sites can override per-page via front-matter.
3. Long-form posts gain reading time and TOC at zero authoring cost. Themes opt in.
4. Code blocks get a copy button. Math renders inline and as block. Both gracefully degrade if the runtime is unavailable.
5. Build performance stays acceptable: idempotent re-builds skip work via a content-hash cache.
6. No new mandatory native dependency. Reuse the existing Node shell-out pattern (already used for shiki) so the toolchain footprint stays at "Swift + Node 20+".

## Non-Goals

- **No runtime image manipulation.** All work is build-time. The browser ships static assets only.
- **No CDN or remote-image support.** Image processing only operates on local files under `static/` and `public/`.
- **No art-direction syntax** (multiple-source per breakpoint with different crops). Single source → multiple widths only.
- **No client-side OG generation.** OG cards are pre-rendered PNGs.
- **No replacement of shiki.** Code-copy buttons sit on top of the existing shiki output.

## Decisions

### Tooling

Reuse the **Node shell-out pattern** already used for shiki:

- `sharp` (libvips bindings) for image resizing / format conversion. Mature, fast, ships prebuilt binaries for macOS and Linux.
- `satori` + `@resvg/resvg-js` for OG card rendering (HTML/JSX → SVG → PNG). Zero browser dependency; same pattern Vercel uses for `next/og`.
- `katex` (npm) for math rendering.

All three become `devDependencies` in `package.json`. `npm ci` is already a prerequisite for `make verify` (shiki). No new prerequisite for the developer; users running `inkwell build` against a Homebrew install need a packaged Node runtime — see "Distribution" below.

### Cache

- Location: `<projectRoot>/.inkwell-cache/{images,og}/`. Gitignored by `inkwell init`.
- Key: SHA-256 of (input bytes + variant params + tool version). Stable across machines; safe to share if a user ever wanted to commit it.
- Eviction: out of scope for v0.6. Cache grows; users prune manually. Revisit if it becomes painful.
- Build skips work entirely when the keyed output already exists.

### Image pipeline

**Trigger**: any `<img src="/...">` or `<img src="static/...">` in rendered HTML, plus front-matter image fields registered via `ProjectChecker.assetFieldNames` (`coverImage`, `shots[].image`, etc.).

**Bypass**: SVG, animated GIF, files under 32 KB, files whose source path includes `/raw/`. Bypass paths still emit width/height attributes but skip variant generation.

**Variants**: 4 widths — 480, 800, 1200, 1600 — capped at the source's intrinsic width. Two formats: original (jpeg/png/webp passthrough or normalized to webp on jpeg input) plus AVIF. Output filenames carry the hash and width: `static/_processed/<hash>-1200.avif`.

**Markup**: a single `<img src=...>` in HTML becomes:

```html
<picture>
  <source type="image/avif" srcset="/_processed/abc123-480.avif 480w, /_processed/abc123-800.avif 800w, …">
  <source type="image/webp" srcset="/_processed/abc123-480.webp 480w, …">
  <img src="/_processed/abc123-1200.webp" width="1200" height="675" loading="lazy" decoding="async" alt="…">
</picture>
```

The pipeline runs as a **post-render HTML pass**, not inside `MarkdownRenderer`. Reasons: (a) front-matter image fields are not in the markdown body; (b) the pass can also handle direct HTML images authors embed; (c) it composes cleanly with `AssetURLRewriter`.

### OG card generation

**Template**: theme-owned. Each theme ships `og/template.html` + `og/styles.css`. Default and quiet themes provide reasonable starters; sites can override under `themes/<theme>/og/`.

**Substitution**: title, author, accent color, optional badge text injected by inkwell before passing to `satori`.

**Output**: `<outputDir>/og/<route-slug>.png` (1200×630 default). Inkwell injects `<meta property="og:image">` and `<meta name="twitter:image">` automatically; front-matter `ogImage: /custom.png` overrides per-page.

**Per-language**: in i18n mode, generate one card per language. Title comes from each language's translated front-matter.

### Reading time

- Compute word count on the rendered HTML body (strip tags + entities). 200 WPM constant; round up to nearest minute.
- Expose `post.readingTime` (Int, minutes) and `post.readingTimeLabel` (e.g. `"5 min read"`) in template context.
- Theme decides whether to render. Default theme: post detail header. Quiet theme: post + case-study detail headers.
- Configurable strings via `themeCopy.readingTimeLabel` (e.g. `"%d min read"` → translated).

### Table of contents

- Pre-render pass adds `id` attributes to `<h2>` / `<h3>` (slugified heading text, deduplicated) — done unconditionally so anchor links work regardless of TOC opt-in.
- TOC structure (`page.toc: [{level, text, anchor, children?}]`) computed when present.
- Opt-in per page via front-matter `toc: true`. Themes render `{% if page.toc %}{% include "toc.html" %}{% endif %}`.
- Quiet theme: case-study layout opts in by default for items with > 3 h2s (no front-matter toggle needed).

### Code-copy buttons

- Pure client-side. Theme assets ship `assets/js/code-copy.js`. Hook: every `<pre>` block.
- Button is theme-styled; default + quiet themes get matching designs.
- Falls back gracefully when JS is disabled (button absent, code block intact).

### KaTeX math

- Detect math markers in markdown body (`$...$` inline, `$$...$$` block). Auto-detect — no front-matter opt-in.
- Server-side render via `scripts/render-math.mjs` (Node + `katex`). Same shellout shape as shiki.
- Inkwell injects KaTeX CSS into `<head>` only when the page contains math. No KaTeX JS at runtime; HTML-only output.
- Math rendering happens inside `MarkdownRenderer` (parallel to shiki for code), so the pipeline stays linear.

### Distribution

`inkwell` is distributed via Homebrew. Users running a published binary need Node + `node_modules/`. Two options:

- **A.** Document Node + `npm install` as a prerequisite alongside Inkwell. Add `inkwell doctor` (separate ticket) that surfaces missing tools clearly. **Preferred.**
- **B.** Bundle Node as a Homebrew dependency. Cleaner for the user; heavier formula; harder to manage when sharp ships native binaries.

We pick (A). Image pipeline + OG + math gracefully degrade when Node is missing: image becomes a plain `<img>` with intrinsic dimensions; OG card emission is skipped (warning); math falls through as raw markdown. Builds keep succeeding; the site just looks less polished. This matches how shiki already behaves.

## Open questions

1. **Theme switching breaks the image cache?** Variant params don't depend on theme — same cache works across themes. OG cache does, since the template is theme-owned; key on theme version.
2. **Should we ship a fallback OG card when the theme has no template?** Lean yes — a plain "site title — page title" card is better than no card. Inkwell-bundled default.
3. **Should reading time show on the home / list pages?** Probably not by default (clutter). Themes decide.
4. **Auto-detecting math has false positives in posts about money (`$5`).** Mitigation: require a digit/letter immediately on either side of the `$` for inline math, and `$$` to be at line start for block math. If false positives surface, add front-matter `math: false` to opt out.
5. **Should we expose the variant set in `blog.config.json`?** Defer until we hear demand. Sensible defaults are usually right.

## Out of scope (revisit later)

- **Webmentions** receiver/sender.
- **Pinned posts** / sticky entries.
- **Author pages / multi-author bylines.** krisbaker.com is single-author.
- **Comment systems.** Giscus / Utterances stub left for users to drop in via `head.html`.
- **AVIF-only output (drop WebP)** — wait until Safari-shipping AVIF is universal, which it now nearly is. Punt one cycle.
- **Math via MathML instead of KaTeX HTML.** Browser support is now real but inconsistent on iOS. Revisit in a year.
