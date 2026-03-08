# Deploy Setup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an optional `inkwell deploy setup github-pages` command that generates GitHub Pages workflow files without mutating blog configuration.

**Architecture:** Extend the CLI command tree with a deployment namespace and a GitHub Pages setup leaf command. The command reads `blog.config.json` when available to discover the configured output directory, writes a workflow file under `.github/workflows`, and prints follow-up guidance instead of editing project settings.

**Tech Stack:** Swift ArgumentParser, Foundation file I/O, existing `SiteConfig` model from `BlogCore`, XCTest.

---

### Task 1: Add failing CLI tests

**Files:**
- Create: `Tests/BlogCLITests/DeployCommandTests.swift`
- Modify: `Sources/BlogCLI/BlogCommand.swift`

**Step 1: Write the failing test**

Add tests that assert:
- `BlogCommand.configuration.subcommands` includes `DeployCommand`
- `DeploySetupGitHubPagesCommand` creates `.github/workflows/pages.yml`
- the workflow content references the configured `outputDir`
- `blog.config.json` is unchanged after setup

**Step 2: Run test to verify it fails**

Run: `swift test --filter DeployCommandTests`
Expected: FAIL because the deploy command types do not exist yet.

### Task 2: Implement the command tree and workflow generation

**Files:**
- Create: `Sources/BlogCLI/Commands/DeployCommand.swift`
- Modify: `Sources/BlogCLI/BlogCommand.swift`
- Reference: `Sources/BlogCore/Models/SiteConfig.swift`

**Step 1: Write minimal implementation**

Add:
- `DeployCommand`
- `DeploySetupCommand`
- `DeploySetupGitHubPagesCommand`

Behavior:
- read `blog.config.json` if present, defaulting `outputDir` to `docs`
- create `.github/workflows`
- write `pages.yml` using the discovered output directory
- print a brief reminder about `baseURL` and enabling Pages

**Step 2: Run test to verify it passes**

Run: `swift test --filter DeployCommandTests`
Expected: PASS

### Task 3: Document the optional hosting flow

**Files:**
- Modify: `README.md`

**Step 1: Update docs**

Add a short section showing:
- `inkwell init`
- `inkwell deploy setup github-pages`
- a brief explanation that deployment setup is optional

**Step 2: Run focused verification**

Run: `swift test --filter BlogCLITests`
Expected: PASS

### Task 4: Verify the final change set

**Files:**
- Review: `Sources/BlogCLI/Commands/DeployCommand.swift`
- Review: `Tests/BlogCLITests/DeployCommandTests.swift`
- Review: `README.md`

**Step 1: Run broader verification**

Run: `swift test`
Expected: PASS
