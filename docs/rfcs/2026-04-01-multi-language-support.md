# RFC: Multi-Language Support

**Status:** Accepted (2026-05-01)
**Date:** 2026-04-01 (proposed) · 2026-05-01 (accepted, plan in `docs/plans/2026-05-01-i18n-implementation-plan.md`)

## Summary

Add multi-language (i18n) support to inkwell, covering both site-level configured text and per-post / per-collection content. Default language at root URLs, translated languages prefixed (`/ja/...`); browser-language detection on first visit; opt-in per file (translations are independent — no requirement to translate everything).

## Motivation

The author lives in Japan with a Japanese wife and family. Some posts and case studies benefit from being available in both English and Japanese. The site should feel natural to readers in either language without tripping over half-translated content.

## Decisions

### URL shape

- Default language at canonical root: `/posts/foo/`, `/work/wolt-cart/`
- Translated languages at prefixed paths: `/ja/posts/foo/`, `/ja/work/wolt-cart/`
- `/<defaultLang>/...` (e.g. `/en/posts/foo/`) emits a thin redirect HTML to the canonical root path so URLs are consistent if shared with the explicit-lang prefix
- `<link rel="alternate" hreflang="...">` for every available translation, plus `hreflang="x-default"` pointing to the default-language version

### Content authoring

File-suffix per BCP-47:

```
content/posts/foo.md       ← default
content/posts/foo.ja.md    ← Japanese translation (optional)
data/resume.yml            ← default
data/resume.ja.yml         ← Japanese (optional)
```

Translations are independent. Untranslated content does not appear in `/<lang>/...` listings — readers see only the default language's content for those entries.

### Config

Single `blog.config.json` with an `i18n` block and a `translations` overlay:

```json
{
  "i18n": { "defaultLanguage": "en", "languages": ["en", "ja"] },
  "heroHeadline": "I build *millions* of...",
  "translations": {
    "ja": {
      "heroHeadline": "数百万人のための...",
      "footerCta": { "headline": "..." },
      "themeCopy": { "workCardCta": "..." }
    }
  }
}
```

Anything not overridden in `translations.<lang>` falls back to the default. Front-matter strings (title, summary, etc.) come from each translation's own markdown file.

### Browser language detection

Small inline script in `<head>` runs on first visit:

1. If `localStorage.lang` is set, no redirect (user already chose).
2. Else if a configured non-default language is the top match in `navigator.languages` AND we are on a default-lang URL, redirect to the prefixed equivalent.
3. Else stay put.

Manual switches via the language switcher set `localStorage.lang` so the choice persists.

### Search, RSS, sitemap

- Search index: scoped per language; the runtime picks the right index based on the page's `lang`.
- RSS: one feed per language at `/rss.xml` (default) and `/<lang>/rss.xml`.
- Sitemap: single sitemap with all language variants enumerated.

(Search/RSS/sitemap details belong to follow-up scope; v1 ships routing + content + theme.)

## Out of scope (v1)

- Right-to-left languages (Arabic, Hebrew). Adding them later is mostly a CSS concern, not a routing concern.
- Per-language fonts. The quiet theme already loads fonts that handle Japanese reasonably; can be revisited if the rendering looks off.
- Translation tooling (extracting strings, machine-translation pipelines). Out of scope — translations are hand-authored.
