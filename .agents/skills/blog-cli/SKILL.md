---
name: blog-cli
description: Use when a user wants to operate the Swift personal blog CLI (create projects/posts, build, preview, validate, or manage themes/plugins) and needs command-specific workflows or troubleshooting.
---

# Blog CLI

Use this skill to operate the `blog` command safely and consistently.

## When To Use
- User asks to run or explain `blog` commands.
- User wants a publishing workflow from post creation through validation.
- User needs help with theme/plugin command usage.

## Command Routing
- `blog init` -> `subskills/init.md`
- `blog post new` -> `subskills/post-new.md`
- `blog post list` -> `subskills/post-list.md`
- `blog build` -> `subskills/build.md`
- `blog serve` -> `subskills/serve.md`
- `blog check` -> `subskills/check.md`
- `blog theme list|use` -> `subskills/theme.md`
- `blog plugin list|enable|disable` -> `subskills/plugin.md`

## Standard Flow
1. Initialize once: `blog init`
2. Create content: `blog post new "Title"`
3. Build site: `blog build`
4. Validate output: `blog check`
5. Preview locally: `blog serve --port 8000`

## Guardrails
- Run commands from the blog project root.
- Keep markdown front matter valid (`title`, `date`, `slug`).
- Treat `blog check` failures as release blockers.
- For automation, prefer JSON modes (`blog build --json`, `blog post list --json`, `blog check --json`).
