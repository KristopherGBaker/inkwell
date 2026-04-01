# RFC: Multi-Language Support

**Status:** Idea
**Date:** 2026-04-01

## Summary

Add multi-language (i18n) support to inkwell, covering both site-level configured text (index page, navigation, labels) and per-post content, with the ability to have a single post available in multiple languages.

## Motivation

The author lives in Japan with a Japanese wife and family. Some posts would benefit from being available in both English and Japanese. The site should feel natural to readers in either language.

## Requirements

### Site-level i18n
- Index page configured text (title, description, tagline, labels like "Search entries", "Archive", "Toggle Theme") should support per-language variants in blog.config.json.
- Default language selection based on the user's browser `Accept-Language` header (static site, so this would need to be client-side JS).
- Fall back to English if no match.

### Post-level i18n
- A single post can have content in multiple languages (e.g., English and Japanese).
- Reader can toggle between languages manually on the post page.
- Posts may exist in only one language (no requirement to translate everything).

### Open questions
- File structure: separate markdown files per language (e.g., `post.en.md`, `post.ja.md`) vs. a single file with language-delimited sections?
- URL structure: `/posts/slug/` with client-side toggle, or `/en/posts/slug/` and `/ja/posts/slug/` as separate routes?
- How does this interact with search index generation?
- RSS feed: one feed per language, or a single mixed feed?
