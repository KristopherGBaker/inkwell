# Umami Event Tracking Plan

**Date:** 2026-06-04
**Branch:** `umami-events`
**Target:** Bundled `quiet` (and `default`) themes — opt-in click / outbound-link / download tracking on top of the existing page-view integration.

Builds directly on the [Umami analytics plan](2026-05-06-umami-analytics-plan.md). Test-driven where practical; each phase ends green.

## Goal

The v0.9 Umami integration injects only the base `script.js` tag, so themes record page views and nothing else. This adds a first-class, **opt-in** event layer that captures the conversions a portfolio/blog cares about — résumé downloads, GitHub/LinkedIn clicks, email CTAs, and outbound/file links anywhere on the page — using Umami's two native mechanisms.

## Design notes

Two complementary mechanisms, both gated behind a new `analytics.umami.events` block. Existing sites are unaffected until they opt in.

1. **Auto-tracker (inline JS).** A single delegated `click` listener fires `umami.track("outbound-link", …)` / `umami.track("download", …)`. This is the only thing that can reach links inside rendered Markdown bodies. Shipped **inline in `base.html`**, right after the existing Umami tag, mirroring the existing language-redirect IIFE — so it's gated by the same mode-aware analytics context with no `ThemeManager`/asset-prefix plumbing. Downloads take precedence over outbound (one event per click). A link is a download when it has a `download` attribute or its path ends in a tracked extension.

2. **Declarative `data-umami-event` attributes.** Baked into the `quiet` theme's known CTAs for clean, semantic names. Gated per element by `{% if site.analytics.umami.events.themeElements %}`.

Because the whole `events` sub-context hangs off the effective Umami block resolved by `analyticsContext(for:mode:)`, build-mode behavior is inherited for free: serve mode without a `local` block emits no tracker and no attributes.

| Mode | Behavior |
|---|---|
| `inkwell build` | Renders tracker + attributes per the top-level `events` block. |
| `inkwell serve --watch` | Uses `local.events` if a `local` block is present; emits nothing otherwise. |

## Event catalog

| Trigger | Event | Properties | Mechanism |
|---|---|---|---|
| External link (host ≠ site host) | `outbound-link` | `url` | auto |
| Download (`download` attr or tracked extension) | `download` | `file`, `url` | auto |
| Résumé PDF download | `resume-download` | — | declarative |
| Résumé print button | `resume-print` | — | declarative |
| Email (footer / about / résumé / post reply) | `email` | — | declarative |
| Social links (footer / résumé) | `social` | `network` | declarative |
| Landing hero primary / secondary CTA | `cta-hero-primary` / `cta-hero-secondary` | — | declarative |

Default download extensions: `pdf, zip, dmg, csv, xlsx, doc, docx, pptx, mp3, mp4, png, jpg, svg` (override via `downloadExtensions`).

## Phases

### Phase 1 — Config schema
- `Sources/BlogCore/Models/AnalyticsConfig.swift` — new `UmamiEventsConfig { outboundLinks?, downloads?, themeElements?, downloadExtensions? }` (all `Codable, Equatable`). Add `events: UmamiEventsConfig?` to **both** `UmamiConfig` and `UmamiLocalConfig` (local inherits nothing).
- Tests in `SiteConfigTests`: full block, partial block, events-in-local, and `events == nil` for the minimal config.

### Phase 2 — Surface in context
- `PageContextBuilder.analyticsContext(for:mode:)` — capture `events` per mode and attach `umamiCtx["events"]` via a new `eventsContext(_:)` helper. The helper returns nil unless at least one flag is on, and always resolves `downloadExtensions` to the config override or `defaultDownloadExtensions` so the template can render a JS array unconditionally. Extension strings escaped via `escapeHTML`.

### Phase 3 — Render in themes
- Auto-tracker inline `<script>` after the Umami tag in `quiet` **and** `default` `base.html`, gated on `events.outboundLinks or events.downloads`. Uses only Stencil features already in the templates (`or`, `for` + `forloop.last`, `if/else`).
- Declarative attributes (gated on `events.themeElements`) in `quiet` templates: `layouts/resume.html`, `partials/footer.html`, `layouts/about.html`, `layouts/post.html`, `layouts/landing.html`. Default-theme declarative attributes are a follow-up.

### Phase 4 — Tests
- `QuietThemeAnalyticsTests` (build/serve + assert on `docs/index.html`): auto-tracker renders when enabled; omitted with no `events` block; custom extensions override the default; `themeElements` renders `data-umami-event` (asserted via footer email/social, present on every page); attributes omitted when the flag is off; serve-without-local emits nothing.

### Phase 5 — Docs / version
- Extend the "Analytics (Umami)" section of `docs/getting-started.md` with the `events` block and event catalog.
- Bump `Sources/BlogCLI/Version.swift` 0.9.3 → 0.10.0.

## Verification

1. `swift test` — full suite green.
2. Build a real site with an `events` block; confirm the inline tracker renders in `docs/index.html` and `data-umami-event="resume-download"` appears on `docs/resume/index.html`.
3. `inkwell serve --watch` with no `local.events` → no tracker (dev safety).
4. Smoke: stub `window.umami`, click an outbound link and the résumé download, confirm one `umami.track` call each.
