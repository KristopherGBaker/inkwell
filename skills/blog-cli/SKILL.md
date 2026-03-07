---
name: blog-cli
description: Use when a user wants to operate the Swift personal inkwell CLI (create projects/posts, build, preview, validate, or manage themes/plugins) and needs command-specific workflows or troubleshooting.
---

# Blog CLI

Use this skill to operate the `inkwell` command safely and consistently.

## When To Use
- User asks to run or explain `inkwell` commands.
- User wants a publishing workflow from post creation through validation.
- User needs help with theme/plugin command usage.

## Command Routing
- `inkwell init` -> `subskills/init.md`
- `inkwell post new` -> `subskills/post-new.md`
- `inkwell post list` -> `subskills/post-list.md`
- `inkwell build` -> `subskills/build.md`
- `inkwell serve` -> `subskills/serve.md`
- `inkwell check` -> `subskills/check.md`
- `inkwell theme list|use` -> `subskills/theme.md`
- `inkwell plugin list|enable|disable` -> `subskills/plugin.md`

## Standard Flow
1. Initialize once: `inkwell init`
2. Create content: `inkwell post new "Title"`
3. Build site: `inkwell build`
4. Validate output: `inkwell check`
5. Preview locally: `inkwell serve --port 8000`

## Guardrails
- Run commands from the inkwell project root.
- Keep markdown front matter valid (`title`, `date`, `slug`).
- Treat `inkwell check` failures as release blockers.
- For automation, prefer JSON modes (`inkwell build --json`, `inkwell post list --json`, `inkwell check --json`).
