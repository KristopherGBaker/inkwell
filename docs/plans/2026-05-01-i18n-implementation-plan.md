# i18n Implementation Plan

**RFC:** `docs/rfcs/2026-04-01-multi-language-support.md`
**Date:** 2026-05-01
**Branch:** `i18n` (worktree at `../inkwell-i18n`)
**Target:** krisbaker.com (English default, Japanese optional)

Test-driven where practical. Each phase ends with a green build and at least one new test.

## Phase 1 — Config schema

Goal: parse the `i18n` block and `translations` overlay; preserve full backwards compatibility.

- [ ] `Sources/BlogCore/Models/I18nConfig.swift` — `defaultLanguage: String` (default `"en"`), `languages: [String]` (default `[defaultLanguage]`).
- [ ] `SiteConfig.i18n: I18nConfig?` + decode.
- [ ] `SiteConfig.translations: [String: [String: Any]]?` — opaque per-language overlay dict (decode via `JSONSerialization` since it's heterogeneous).
- [ ] Tests: legacy config (no i18n) still decodes; full i18n config decodes; partial translations dict accepted.

## Phase 2 — Content loading

Goal: detect `<base>.<lang>.<ext>` and pair translations to the same `slug`.

- [ ] Extend `ContentLoader` to parse a `(slug, lang)` tuple from filenames.
- [ ] `CollectionItem` gains `lang: String` and `availableLanguages: [String]` (or equivalent — every loaded item knows its lang and which other langs exist for the same slug).
- [ ] Default-lang items keep their canonical `slug`; non-default-lang items inherit the same slug but carry `lang: "ja"`.
- [ ] Tests: untranslated post (no `.ja.md`) → one `CollectionItem` with `lang: "en"`, `availableLanguages: ["en"]`. Fully translated post → two items, each pointing at the same `availableLanguages: ["en", "ja"]`.

## Phase 3 — Page loading

Same shape as Phase 2 but for `content/pages/`.

- [ ] `Page` gains `lang` + `availableLanguages`.
- [ ] Tests covering same scenarios for pages.

## Phase 4 — Data loading

Goal: `data/resume.ja.yml` is reachable when rendering Japanese pages.

- [ ] `DataLoader` returns `[lang: [String: Any]]` instead of flat `[String: Any]`.
- [ ] Falls back to default-language data when a `<lang>` variant is missing.
- [ ] Tests: missing `.ja.yml` falls back to default; present `.ja.yml` is preferred when rendering ja.

## Phase 5 — Routing + URL prefixing

Goal: emit per-language plans with the right URLs.

- [ ] `PageContextBuilder` emits one plan per `(item, lang)` pair.
- [ ] URL builder helper: `urlBuilder.localized(route:, lang:)` — root path for default lang; `/<lang>/...` for non-default.
- [ ] `page.lang`, `page.translations` (array of `{lang, label, href}` for the OTHER available languages), and `site.languages` exposed in template context.
- [ ] Site-level fields (`heroHeadline`, `footerCta`, `themeCopy`, `home.*` labels, `tagline`, `description`) merged from `siteConfig` ⊕ `siteConfig.translations[lang]` — non-default langs see overridden values where set, default elsewhere.
- [ ] Tests: ja plan exists at `/ja/posts/foo/`, en plan at `/posts/foo/`. `page.translations` contains the alternate. Overlay merges correctly.

## Phase 6 — `/en/` alias redirects

Goal: `/en/posts/foo/` resolves to a redirect to `/posts/foo/`.

- [ ] Emit thin HTML redirect pages at `/<defaultLang>/<route>/` for each default-language route.
- [ ] Redirect template: `<meta http-equiv="refresh" content="0; url=...">` + `<link rel="canonical">` + visible "Redirecting…" text.
- [ ] Tests: redirect plan emitted; `<head>` contains expected meta tags.

## Phase 7 — Theme

Goal: hreflang tags, language switcher, browser detection script.

- [ ] `<link rel="alternate" hreflang="...">` per available translation, injected via `ThemeManager` (default + quiet themes).
- [ ] Quiet theme's `top-bar.html` gets a language switcher partial — only shows when `site.languages > 1`. Switcher links to the current page's translation, or to the language root if no translation exists.
- [ ] `quiet/assets/js/lang-switch.js`: detects browser language on first visit, redirects to non-default if preferred, persists choice in `localStorage`.
- [ ] Tests: hreflang tags inject correctly; switcher renders given the right context.

## Phase 8 — krisbaker.com integration

Goal: prove both languages render end-to-end.

- [ ] `i18n` block + `translations.ja` overlay in `blog.config.json`.
- [ ] Translate one post (`content/posts/foo.ja.md`), one project (`content/projects/wolt-cart-entry-points.ja.md`), one page (`content/pages/about.ja.md`), and `data/resume.ja.yml`.
- [ ] Verify: `/ja/posts/foo/`, `/ja/work/wolt-cart-entry-points/`, `/ja/about/`, `/ja/resume/` all render with Japanese content; `/en/...` redirects to `/...`; language switcher in the top-bar swaps URLs correctly; `<link rel="alternate" hreflang="ja">` appears on both English and Japanese pages.

Only after Phase 8 lands cleanly do we open inkwell PRs.

## Conventions

- All new public types `Codable, Equatable`.
- Keep diffs from `main` minimal where touching shared code (don't refactor opportunistically; this is a feature branch, not a cleanup branch).
- Tests live alongside the code they exercise (`Tests/BlogCoreTests/...`, `Tests/BlogThemesTests/...`).
- Ship small commits per phase so the PR series can be reviewed incrementally if needed.
