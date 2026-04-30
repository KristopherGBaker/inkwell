---
name: blog-cli
description: Use when a user wants to operate the Swift inkwell CLI — create projects, scaffold posts/collection items, build, preview, validate, manage themes/plugins, or deploy. Routes to per-command subskills.
---

# Inkwell CLI

Use this skill to operate the `inkwell` command safely and consistently. Inkwell is a Swift static publishing tool; v0.3+ supports both blogs and portfolio sites.

## When To Use
- User asks to run or explain `inkwell` commands.
- User wants a publishing workflow from content creation through validation.
- User needs help scaffolding new collection items, customizing themes, or deploying.

## Command Routing
- `inkwell init` → `subskills/init.md`
- `inkwell post new|list|publish` → `subskills/post-new.md`, `subskills/post-list.md`
- `inkwell content new <collection>` → `subskills/content-new.md`
- `inkwell build` → `subskills/build.md`
- `inkwell serve` (with `--watch`) → `subskills/serve.md`
- `inkwell check` → `subskills/check.md`
- `inkwell theme list|use` → `subskills/theme.md`
- `inkwell plugin list|enable|disable` → `subskills/plugin.md`

## Standard Flows

### Blog
1. Scaffold: `inkwell init`
2. Create draft: `inkwell post new "Title"` (creates `draft: true`)
3. Edit, then publish: `inkwell post publish <slug>`
4. Build: `inkwell build`
5. Validate: `inkwell check`
6. Preview locally: `inkwell serve --watch`

### Portfolio (or blog + portfolio)
1. Scaffold: `inkwell init`
2. Edit `blog.config.json`: set `theme: "quiet"`, add `author`/`nav`/`home`/`collections`. (See the `site-setup` skill for an interactive walkthrough.)
3. Scaffold a project: `inkwell content new projects "Title"`
4. Add data: drop `data/experience.yml`, `data/competencies.yml`, etc. (See the `portfolio-data` skill.)
5. Add the résumé shell: `content/pages/resume.md` with `layout: resume` and an empty body.
6. Build: `inkwell build`
7. Validate: `inkwell check`

## Guardrails
- Run all commands from the inkwell project root (the directory containing `blog.config.json`).
- Keep markdown front matter valid: `title`, `slug`, plus `date` (posts) or `year` (year-sorted collections like projects).
- Treat `inkwell check` failures as release blockers.
- For automation/scripting, prefer JSON modes: `inkwell build --json`, `inkwell post list --json`, `inkwell check --json`.
- Asset paths in front matter must be `/assets/...` (resolved from `static/assets/` or `public/assets/`) or fully-qualified `https://...`. Relative paths like `assets/foo.png` are rejected by `inkwell check`.

## Related Skills
- `site-setup` — interactive walkthrough for initial project configuration (blog vs portfolio vs combined).
- `theme-customize` — guides overriding bundled theme templates/assets per file.
- `portfolio-data` — imports résumé/CV content into `data/*.yml`.
- `blog-writing` — voice profile + post drafting workflow.
