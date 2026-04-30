# Inkwell Roadmap

## Goal

Evolve `inkwell` from a solid core static blog generator into a more polished publishing tool with stronger authoring workflow, richer site features, and a clearer extensibility story.

## Principles

- Prioritize features that improve day-to-day writing and publishing
- Prefer host-agnostic and theme-agnostic capabilities in core
- Keep deployment targets optional and modular
- Add platform features only after the core authoring loop feels excellent

## Current Strengths

- Markdown authoring with front matter
- Post scaffolding, listing, and publishing workflow
- Static site build and local preview
- GFM features, Mermaid, and syntax highlighting
- Tags, categories, pagination, RSS, sitemap, `robots.txt`, and search index
- Optional GitHub Pages setup

## Near-Term Roadmap

### v0.2 - Authoring and Publishing Polish

**Objective:** make the core writing and publishing workflow feel fast, safe, and complete.

#### 1. Watch Mode and Live Reload
- Add `inkwell serve --watch`
- Rebuild automatically on content, theme, or config changes
- Trigger browser refresh after successful rebuilds

#### 2. Archive Page
- Add a chronological archive page for published posts
- Link it from the main site navigation
- Support grouping by year and month if useful

#### 3. SEO Metadata
- Generate canonical URLs on post and index pages
- Add Open Graph and Twitter card metadata
- Ensure shared metadata can be overridden cleanly when needed

#### 4. Validation Improvements
- Extend `inkwell check` beyond internal links
- Validate front matter completeness and consistency
- Catch missing assets, invalid cover image references, and malformed config values

### v0.3 - Content Collections + Templating Migration (Shipped)

**Status:** shipped. See `docs/rfcs/2026-04-30-content-collections-and-templating.md` and `docs/plans/2026-04-30-v0-3-implementation-plan.md`.

#### Shipped
- Stencil-based templating; HTML moved out of `RouteBuilder.swift` into theme templates owned by themes
- Generic content collections via `blog.config.json` (`collections: [{id, dir, route, sortBy, taxonomies, ...}]`)
- Standalone pages from `content/pages/`, with theme-resolved layouts
- Data files (`data/*.yml|json`) exposed in template contexts under `data.<name>`
- Configurable home page (`home.template`, `home.featuredCollection`, `home.recentCollection`)
- `author`, `nav` site-identity config, with the `quiet` theme rendering them
- `inkwell content new <collection> "<title>"` scaffolding for any declared collection
- Asset path validation in `inkwell check` (rejects relative paths, surfaces missing files)
- Bundled `quiet` theme covering landing, work-list, case-study, post, page, post-list, taxonomy, 404, and resume layouts
- `portfolio-data` skill for importing résumé content into `data/*.yml`

### Deferred / Future Workflows

**Objective:** support more realistic long-term blogging workflows.

#### Scheduled Publishing
- Support future-dated posts without rendering them publicly before publish time
- Make preview behavior explicit for scheduled content
- Surface schedule state in CLI post listing

#### Series Support
- Promote the existing `series` concept into user-facing site behavior
- Add series navigation on posts
- Add a series landing/index page if the model supports it cleanly

#### Redirects and Permalink Stability
- Add redirects for renamed or moved posts
- Support simple redirect definitions in config or front matter
- Help preserve links when URL structures evolve

#### Shortcodes and Embeds
- Add a lightweight embed/shortcode model for common rich content
- Target practical cases like YouTube, GitHub gists, and callout-style blocks
- Keep it simple and avoid turning posts into full application templates

## Mid-Term Roadmap

### v0.4 - Better Presentation and Discovery

**Objective:** make generated sites feel more polished without overcomplicating content authoring.

#### 9. Image Pipeline
- Add image resizing and responsive variants
- Generate width/height metadata automatically
- Support thumbnails and social sharing images more cleanly

#### 10. Related Content
- Add related posts using tags, categories, or series membership
- Improve content discovery without adding noisy recommendations

#### 11. Theme Extensibility (Partial — shipped in v0.3)
- ~~Stencil-backed templates owned by themes; default + quiet themes ship with the binary~~ — shipped
- ~~Project-side `themes/<name>/templates/` shadow bundled templates file-by-file~~ — shipped
- Remaining: stable theme manifest schema, third-party theme installation, theme versioning

#### 12. Additional Deployment Setup Targets
- Keep deployment setup optional
- Add scaffolds for more hosts over time, such as Netlify or Cloudflare Pages
- Avoid hard-coding host assumptions into `init`

## Long-Term Roadmap

### v0.5+ - Platform Capabilities

**Objective:** grow carefully into a broader publishing platform only after the core experience is strong.

#### 13. Stable Plugin Architecture
- Define supported hooks and lifecycle points clearly
- Make plugin behavior predictable and safe
- Support future integrations without bloating core

#### 14. Data Files and Computed Content (Shipped in v0.3)
- ~~Support YAML/JSON data files for richer pages~~ — shipped
- ~~Enable non-post content such as projects, links, notes, or custom collections~~ — shipped
- TOML support remains future work

#### 15. Faster Incremental Builds
- Reduce rebuild time during active authoring
- Rebuild only affected pages when possible
- Improve feedback loop for larger sites

#### 16. Internationalization
- Add multilingual support only if the content model stays understandable
- Support language-specific routes, feeds, and metadata

#### 17. CMS or Editor Integrations
- Explore lightweight editorial workflows after the file-based workflow is mature
- Keep this optional rather than redefining the product around hosted editing

## Priority Order

1. Watch mode and live reload
2. Archive page
3. SEO metadata
4. Validation improvements
5. Scheduled publishing
6. Series support
7. Redirects
8. Shortcodes and embeds
9. Image pipeline
10. Theme extensibility
11. Stable plugin architecture

## Why This Order

- The first group improves the daily author experience immediately
- The middle group helps sites age well as content grows
- The last group expands platform capability once the fundamentals are dependable

## Nice-to-Have Ideas to Revisit Later

- Reading time and table of contents generation
- Menu configuration and breadcrumbs
- Multiple feed formats beyond RSS
- Social/comment/newsletter integrations
- Better theme/starter discovery and sharing
- Content collections beyond standard blog posts

## Success Criteria

The roadmap is working if:

- publishing a post feels fast and low-friction
- common mistakes are caught before deploy
- generated sites feel polished enough for long-term personal publishing
- new capabilities can be added without overloading `init` or the core CLI surface
