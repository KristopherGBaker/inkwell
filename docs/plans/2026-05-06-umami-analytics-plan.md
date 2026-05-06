# Umami Analytics Plan

**Date:** 2026-05-06
**Branch:** `umami-analytics`
**Target:** krisbaker.com (self-hosted Umami at `analytics.krisbaker.com`, plus a localhost instance for development)

Test-driven where practical. Each phase ends with a green build and at least one new test.

## Goal

First-class, opt-in Umami analytics. Sites declare their Umami instance in `blog.config.json` and the bundled themes inject the script tag with the correct `data-*` attributes. A separate `local` block lets the user run a local Umami against `inkwell serve --watch` without polluting the production instance — and lets the prod instance never see localhost events.

## Design notes

Umami's official integration is a single `<script defer>` tag with `data-*` attributes (`data-website-id`, `data-host-url`, `data-domains`, `data-do-not-track`, `data-tag`, etc.). No JS dependency, no cookies, GDPR-compliant by default.

Two states the build has to distinguish:

| Mode | Source | Behavior |
|---|---|---|
| `inkwell build` (and any non-serve invocation) | top-level `analytics.umami` block | Inject the prod script, pinned to `data-domains: "krisbaker.com"` so localhost browsing in a stale dev tab can never report into prod. |
| `inkwell serve --watch` | `analytics.umami.local` block (if present) | Inject the local script, pointed at the developer's localhost Umami. If `local` is missing, inject **nothing**. |

`local` inherits no fields from the prod block — fully independent. This keeps secrets / IDs / domains explicit and avoids surprise composition.

Rendering happens inside the bundled `base.html` for each theme (Stencil `{% if %}` per `data-*` attr). `ThemeManager.injectHeadAssets` was an alternative, but the conditional `data-*` attributes map more cleanly to Stencil syntax than to Swift string concatenation, and head injection is already a per-theme concern (`base.html` renders `<head>` already).

`BuildMode` ships as a small enum on `BuildPipeline` so `ServeCommand` can tell the pipeline it's running in serve context. Nothing else in the pipeline branches on it yet, but it's the natural anchor for any future serve-vs-build-only behavior.

## Phase 1 — Config schema

Goal: parse the new `analytics.umami` block (with optional `local` override).

- [ ] `Sources/BlogCore/Models/AnalyticsConfig.swift` — `AnalyticsConfig { umami: UmamiConfig? }`, `UmamiConfig { scriptUrl, websiteId, hostUrl?, domains?, respectDoNotTrack?, tag?, local: UmamiLocalConfig? }`, `UmamiLocalConfig { scriptUrl, websiteId, hostUrl?, domains?, respectDoNotTrack?, tag? }`. All `Codable, Equatable`.
- [ ] `SiteConfig.analytics: AnalyticsConfig?` + decode (mirrors how `brandIcon` was added in v0.8.0).
- [ ] Tests in `SiteConfigTests`: legacy config (no `analytics` key) decodes; prod-only block decodes; prod + local block decodes; partial block (no `local`) decodes.

## Phase 2 — Build mode

Goal: pipeline knows whether it's running for serve or one-shot build.

- [ ] `Sources/BlogCore/BuildMode.swift` — `public enum BuildMode { case build, serve }`.
- [ ] `BuildPipeline.run(in:, mode: BuildMode = .build)` — default preserves all existing call sites.
- [ ] `ServeCommand` passes `mode: .serve` into `pipeline.run`.
- [ ] Tests: existing build pipeline tests still pass with the default arg; one new test asserts `serve` mode propagates to `PageContextBuilder` (via the analytics surface check below).

## Phase 3 — Surface in template context

Goal: `site.analytics.umami.{scriptUrl,websiteId,…}` resolves to the right block per `BuildMode`.

- [ ] `PageContextBuilder` accepts `mode: BuildMode`.
- [ ] When `mode == .serve` and `analytics.umami.local` is present, expose its fields as `site.analytics.umami` (light flattening — templates only see one effective block, never both).
- [ ] When `mode == .serve` and `analytics.umami.local` is absent, expose `nil` (template injects nothing).
- [ ] When `mode == .build`, expose top-level `analytics.umami`.
- [ ] Pre-escape values via `escapeHTML` since they land inside HTML attributes.
- [ ] Tests in `PageContextBuilderTests` (or a new `AnalyticsContextTests`): build-mode picks prod; serve-mode picks local; serve-mode with no local emits nothing; missing config in either mode emits nothing.

## Phase 4 — Render in `base.html`

Goal: bundled themes inject the script tag with the right `data-*` attributes when configured.

- [ ] Update `Sources/BlogThemes/Resources/themes/quiet/templates/base.html` and `Sources/BlogThemes/Resources/themes/default/templates/base.html` (whichever exists) to render, just before `</head>`:

  ```stencil
  {% if site.analytics.umami %}<script defer src="{{ site.analytics.umami.scriptUrl }}" data-website-id="{{ site.analytics.umami.websiteId }}"{% if site.analytics.umami.hostUrl %} data-host-url="{{ site.analytics.umami.hostUrl }}"{% endif %}{% if site.analytics.umami.domains %} data-domains="{{ site.analytics.umami.domains }}"{% endif %}{% if site.analytics.umami.respectDoNotTrack %} data-do-not-track="true"{% endif %}{% if site.analytics.umami.tag %} data-tag="{{ site.analytics.umami.tag }}"{% endif %}></script>{% endif %}
  ```

- [ ] Tests in `QuietThemeIntegrationTests` (or a new `QuietThemeAnalyticsTests`): rendered HTML contains the `<script defer>` tag with the right `src`, `data-website-id`, and conditional `data-*` attrs when configured; HTML omits the tag entirely when `analytics.umami` is unset; verify the same in the default theme if it has its own `base.html`.

## Phase 5 — Documentation

- [ ] One paragraph in `docs/getting-started.md`: how to opt in (`analytics.umami` block), what the `local` override does, recommended `data-domains` setting for prod isolation, and the privacy defaults (`respectDoNotTrack: true`).
- [ ] Top of `Sources/BlogCore/Models/AnalyticsConfig.swift` carries doc comments matching `BrandIconConfig.swift`'s style — describe each field and the `local` override semantics.

## Phase 6 — krisbaker.com integration

Goal: prove the wiring end-to-end against a real Umami instance.

- [ ] `analytics.umami` block in `krisbaker.com/blog.config.json` pointing at `https://analytics.krisbaker.com/script.js` with the prod website ID and `data-domains: "krisbaker.com"`.
- [ ] `analytics.umami.local` block pointing at `http://localhost:3000/script.js` (or wherever the local Umami instance lives) with a separate dev website ID and `data-domains: "localhost"`.
- [ ] Verify locally:
  - `inkwell build` → rendered HTML carries the prod script.
  - `inkwell serve --watch` → rendered HTML carries the local script.
  - Loading the served pages in a browser reports events to the local Umami dashboard.
- [ ] Verify in production after deploy: events show up in the prod Umami dashboard; localhost loads (with stale tabs hitting prod-domain pages somehow) don't.

Only after Phase 6 lands cleanly do we open the inkwell PR.

## Conventions

- All new public types `Codable, Equatable`.
- Default args on `BuildPipeline.run` so the change is non-breaking for existing call sites and tests.
- Tests live alongside the code they exercise (`Tests/BlogCoreTests/...`).
- Ship one commit per phase so the PR can be reviewed incrementally if needed.

## Out of scope

- Other analytics providers (Plausible, Fathom, GA, etc.). The `analytics` namespace leaves room for `analytics.plausible` etc. later, but no work in this plan.
- Custom event tracking from theme JS (e.g. tracking the language switcher, theme toggle, code-copy button). Umami auto-tracks page views; bespoke events are a follow-up if/when the user wants funnels.
- Content-aware tagging (e.g. tagging analytics events with the post slug or collection). The optional `tag` field is the only segmentation lever in this iteration.
- Server-side IP-based analytics (Umami runs client-side; outside inkwell's surface).
