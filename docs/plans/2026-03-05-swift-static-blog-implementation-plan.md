# Swift Static Blog + CLI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Swift-based static blog platform with Markdown posts, GFM support, syntax-highlighted code blocks, a first-party CLI, and deployable GitHub Pages output.

**Architecture:** Use a single Swift package with modular targets: `BlogCLI`, `BlogCore`, `BlogRenderer`, `BlogThemes`, `BlogPlugins`, and `BlogPreview`. Build through a deterministic pipeline (load config -> parse content -> validate -> render routes -> copy assets -> write `docs/`) and expose operations through CLI commands.

**Tech Stack:** Swift 6, Swift Package Manager, XCTest, `swift-argument-parser`, GFM parser adapter (`cmark-gfm`-compatible), Prism.js (client-side syntax highlighting assets), GitHub Actions.

---

## Delivery Checklist
- [ ] Package scaffold and module boundaries are in place.
- [ ] CLI commands (`init`, `post new`, `post list`, `build`, `serve`, `check`) are implemented.
- [ ] GFM rendering works for tables, task lists, strikethrough, fenced code blocks.
- [ ] Syntax highlighting works via language classes + Prism assets.
- [ ] Theme system and plugin hooks work with one default implementation each.
- [ ] `swift test` passes locally and in CI.
- [ ] Sample site builds into `docs/` and is ready for GitHub Pages.

## Assumptions
- Search is deferred to v1.1 and excluded from this plan.
- Syntax highlighting is v1 via Prism assets in generated output.
- Plugin execution is local-only in v1.

## Task 1 Checklist (Project Bootstrap)
- [ ] Create package and targets.
- [ ] Add foundational dependencies.
- [ ] Add first smoke tests.
- [ ] Commit bootstrap.

### Task 1: Bootstrap Swift package and module layout

**Files:**
- Create: `Package.swift`
- Create: `Sources/BlogCLI/main.swift`
- Create: `Sources/BlogCore/BuildPipeline.swift`
- Create: `Sources/BlogRenderer/MarkdownRenderer.swift`
- Create: `Sources/BlogThemes/ThemeManager.swift`
- Create: `Sources/BlogPlugins/PluginManager.swift`
- Create: `Sources/BlogPreview/PreviewServer.swift`
- Test: `Tests/BlogCoreTests/BuildPipelineSmokeTests.swift`

**Step 1: Write the failing smoke test**

```swift
import XCTest
@testable import BlogCore

final class BuildPipelineSmokeTests: XCTestCase {
    func testPipelineConstructs() {
        XCTAssertNoThrow(BuildPipeline())
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter BuildPipelineSmokeTests/testPipelineConstructs`
Expected: FAIL because `BuildPipeline` is missing.

**Step 3: Add minimal implementation**

```swift
public struct BuildPipeline {
    public init() {}
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter BuildPipelineSmokeTests/testPipelineConstructs`
Expected: PASS.

**Step 5: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "chore: bootstrap swift package and module targets"
```

## Task 2 Checklist (Configuration + Content Models)
- [ ] Define config schema.
- [ ] Define front matter schema.
- [ ] Add validation tests.
- [ ] Commit models/config.

### Task 2: Implement configuration and front matter schema

**Files:**
- Create: `Sources/BlogCore/Models/SiteConfig.swift`
- Create: `Sources/BlogCore/Models/PostFrontMatter.swift`
- Create: `Sources/BlogCore/Validation/SchemaValidator.swift`
- Test: `Tests/BlogCoreTests/SchemaValidatorTests.swift`

**Step 1: Write failing schema tests**

```swift
func testMissingRequiredTitleFailsValidation() {
    let fm = PostFrontMatter(title: nil, date: "2026-03-05", slug: "test")
    XCTAssertThrowsError(try SchemaValidator.validate(frontMatter: fm))
}
```

**Step 2: Run tests to verify failure**

Run: `swift test --filter SchemaValidatorTests`
Expected: FAIL due to missing model/validator.

**Step 3: Implement minimal models + validator**
- Required fields: `title`, `date`, `slug`
- Optional fields: `summary`, `tags`, `categories`, `draft`, `series`, `canonicalUrl`, `coverImage`

**Step 4: Re-run tests**

Run: `swift test --filter SchemaValidatorTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/BlogCore/Models Sources/BlogCore/Validation Tests/BlogCoreTests
git commit -m "feat: add site config and front matter schema validation"
```

## Task 3 Checklist (GFM Renderer)
- [ ] Add parser adapter interface.
- [ ] Add GFM fixture tests.
- [ ] Render GFM features to HTML.
- [ ] Commit GFM support.

### Task 3: Implement GFM markdown renderer

**Files:**
- Create: `Sources/BlogRenderer/Protocols/MarkdownEngine.swift`
- Create: `Sources/BlogRenderer/Engines/GFMEngine.swift`
- Create: `Tests/BlogRendererTests/GFMEngineTests.swift`
- Create: `Tests/Fixtures/markdown/gfm-sample.md`
- Create: `Tests/Fixtures/html/gfm-sample.html`

**Step 1: Write failing fixture-based test**

```swift
func testGFMFeaturesRenderAsExpectedHTML() throws {
    let markdown = try fixture("markdown/gfm-sample.md")
    let expected = try fixture("html/gfm-sample.html")
    let actual = try GFMEngine().render(markdown)
    XCTAssertEqual(normalize(actual), normalize(expected))
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter GFMEngineTests/testGFMFeaturesRenderAsExpectedHTML`
Expected: FAIL because engine is missing.

**Step 3: Implement engine with required GFM features**
- Tables
- Task lists
- Strikethrough
- Fenced code blocks with `language-*` class output

**Step 4: Re-run tests**

Run: `swift test --filter GFMEngineTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/BlogRenderer Tests/BlogRendererTests Tests/Fixtures
git commit -m "feat: add gfm markdown rendering with fixture tests"
```

## Task 4 Checklist (Syntax Highlighting)
- [ ] Add Prism assets to default theme.
- [ ] Add code-block rendering contract.
- [ ] Add highlighted output tests.
- [ ] Commit highlighting support.

### Task 4: Add syntax highlighting pipeline integration

**Files:**
- Create: `themes/default/assets/js/prism.js`
- Create: `themes/default/assets/css/prism.css`
- Modify: `Sources/BlogRenderer/Engines/GFMEngine.swift`
- Modify: `Sources/BlogThemes/ThemeManager.swift`
- Test: `Tests/BlogRendererTests/CodeHighlightingTests.swift`

**Step 1: Write failing test for code block output contract**

```swift
func testCodeFenceIncludesLanguageClass() throws {
    let html = try GFMEngine().render("```swift\nprint(\"hi\")\n```")
    XCTAssertTrue(html.contains("class=\"language-swift\""))
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter CodeHighlightingTests`
Expected: FAIL if class output is not guaranteed.

**Step 3: Implement minimal changes**
- Ensure renderer emits `language-*` class.
- Ensure default theme includes Prism CSS/JS in layout.

**Step 4: Re-run tests**

Run: `swift test --filter CodeHighlightingTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/BlogRenderer Sources/BlogThemes themes/default/assets Tests/BlogRendererTests
git commit -m "feat: add syntax highlighting support for fenced code blocks"
```

## Task 5 Checklist (Build Pipeline)
- [ ] Implement content discovery.
- [ ] Implement route generation.
- [ ] Implement output writer to `docs/`.
- [ ] Commit build pipeline.

### Task 5: Implement deterministic build pipeline

**Files:**
- Modify: `Sources/BlogCore/BuildPipeline.swift`
- Create: `Sources/BlogCore/Content/ContentLoader.swift`
- Create: `Sources/BlogCore/Routing/RouteBuilder.swift`
- Create: `Sources/BlogCore/Output/OutputWriter.swift`
- Test: `Tests/BlogCoreTests/BuildPipelineIntegrationTests.swift`

**Step 1: Write failing end-to-end build test**

```swift
func testBuildWritesPostAndIndexPages() throws {
    let report = try BuildPipeline().run(in: fixtureProjectURL)
    XCTAssertEqual(report.errors.count, 0)
    XCTAssertTrue(fileExists("docs/index.html"))
    XCTAssertTrue(fileExists("docs/posts/hello-world/index.html"))
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter BuildPipelineIntegrationTests`
Expected: FAIL due to missing pipeline behavior.

**Step 3: Implement minimal pipeline**
- Load markdown from `content/posts/`
- Validate front matter
- Render HTML via renderer
- Emit deterministic output to `docs/`

**Step 4: Re-run tests**

Run: `swift test --filter BuildPipelineIntegrationTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/BlogCore Tests/BlogCoreTests
git commit -m "feat: implement deterministic build pipeline outputting docs"
```

## Task 6 Checklist (CLI Commands)
- [ ] Implement `init`.
- [ ] Implement `post new` and `post list`.
- [ ] Implement `build`, `serve`, `check` wiring.
- [ ] Commit CLI v1 surface.

### Task 6: Implement CLI command surface

**Files:**
- Modify: `Sources/BlogCLI/main.swift`
- Create: `Sources/BlogCLI/Commands/InitCommand.swift`
- Create: `Sources/BlogCLI/Commands/PostNewCommand.swift`
- Create: `Sources/BlogCLI/Commands/PostListCommand.swift`
- Create: `Sources/BlogCLI/Commands/BuildCommand.swift`
- Create: `Sources/BlogCLI/Commands/ServeCommand.swift`
- Create: `Sources/BlogCLI/Commands/CheckCommand.swift`
- Test: `Tests/BlogCLITests/BlogCLITests.swift`

**Step 1: Write failing CLI behavior tests**

```swift
func testPostNewCreatesMarkdownFile() throws {
    let result = try runCLI(["post", "new", "Hello World"], in: tempProject)
    XCTAssertEqual(result.exitCode, 0)
    XCTAssertTrue(fileExists("content/posts/*hello-world*.md"))
}
```

**Step 2: Run tests to verify failure**

Run: `swift test --filter BlogCLITests`
Expected: FAIL because commands are missing.

**Step 3: Implement minimal command handlers**
- Use `ArgumentParser` subcommands.
- Return explicit exit codes.
- Add `--json` output mode on `list`, `check`, `build`.

**Step 4: Re-run tests**

Run: `swift test --filter BlogCLITests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/BlogCLI Tests/BlogCLITests
git commit -m "feat: add v1 cli commands for content and build workflow"
```

## Task 7 Checklist (Theme System)
- [ ] Implement theme manifest loading.
- [ ] Implement `theme list/use`.
- [ ] Add default theme templates.
- [ ] Commit theme support.

### Task 7: Implement theme loading and selection

**Files:**
- Modify: `Sources/BlogThemes/ThemeManager.swift`
- Create: `Sources/BlogThemes/ThemeManifest.swift`
- Create: `themes/default/theme.json`
- Create: `themes/default/templates/layout.html`
- Create: `themes/default/templates/post.html`
- Test: `Tests/BlogThemesTests/ThemeManagerTests.swift`

**Step 1: Write failing theme selection test**

```swift
func testSelectingThemeUpdatesConfig() throws {
    try ThemeManager().useTheme("default", in: projectURL)
    let config = try loadConfig(projectURL)
    XCTAssertEqual(config.theme, "default")
}
```

**Step 2: Run tests to verify failure**

Run: `swift test --filter ThemeManagerTests`
Expected: FAIL.

**Step 3: Implement minimal theme manager + manifest validation**

**Step 4: Re-run tests**

Run: `swift test --filter ThemeManagerTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/BlogThemes themes/default Tests/BlogThemesTests
git commit -m "feat: add theme manifests and default theme selection"
```

## Task 8 Checklist (Plugin Hooks)
- [ ] Implement plugin protocol and hook lifecycle.
- [ ] Implement local plugin loader.
- [ ] Add hook-order test.
- [ ] Commit plugin framework.

### Task 8: Implement plugin runtime and lifecycle hooks

**Files:**
- Modify: `Sources/BlogPlugins/PluginManager.swift`
- Create: `Sources/BlogPlugins/Plugin.swift`
- Create: `Sources/BlogPlugins/PluginContext.swift`
- Modify: `Sources/BlogCore/BuildPipeline.swift`
- Test: `Tests/BlogPluginsTests/PluginManagerTests.swift`

**Step 1: Write failing hook-order test**

```swift
func testHooksRunInExpectedOrder() throws {
    let calls = try runBuildWithRecordingPlugin()
    XCTAssertEqual(calls, ["beforeParse", "afterParse", "beforeRender", "afterRender", "onBuildComplete"])
}
```

**Step 2: Run tests to verify failure**

Run: `swift test --filter PluginManagerTests`
Expected: FAIL.

**Step 3: Implement minimal plugin manager + lifecycle execution**

**Step 4: Re-run tests**

Run: `swift test --filter PluginManagerTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/BlogPlugins Sources/BlogCore Tests/BlogPluginsTests
git commit -m "feat: add plugin runtime and lifecycle hooks"
```

## Task 9 Checklist (Preview + Validation)
- [ ] Implement local static preview server.
- [ ] Implement link and schema checks.
- [ ] Add CLI `check` integration tests.
- [ ] Commit preview and checks.

### Task 9: Implement `serve` and `check` quality gates

**Files:**
- Modify: `Sources/BlogPreview/PreviewServer.swift`
- Create: `Sources/BlogCore/Validation/LinkChecker.swift`
- Modify: `Sources/BlogCLI/Commands/ServeCommand.swift`
- Modify: `Sources/BlogCLI/Commands/CheckCommand.swift`
- Test: `Tests/BlogCLITests/CheckCommandTests.swift`

**Step 1: Write failing check test**

```swift
func testCheckFailsOnBrokenInternalLink() throws {
    let result = try runCLI(["check"], in: fixtureWithBrokenLink)
    XCTAssertNotEqual(result.exitCode, 0)
    XCTAssertTrue(result.stderr.contains("broken link"))
}
```

**Step 2: Run test to verify failure**

Run: `swift test --filter CheckCommandTests`
Expected: FAIL.

**Step 3: Implement minimal checker + preview server**

**Step 4: Re-run tests**

Run: `swift test --filter CheckCommandTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/BlogPreview Sources/BlogCore/Validation Sources/BlogCLI Tests/BlogCLITests
git commit -m "feat: add preview server and content quality checks"
```

## Task 10 Checklist (CI + Docs + Sample Site)
- [ ] Add CI workflow.
- [ ] Add getting-started docs.
- [ ] Add sample content proving GFM + highlighting.
- [ ] Commit hardening/docs.

### Task 10: Add CI, docs, and sample project fixtures

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `README.md`
- Create: `docs/getting-started.md`
- Create: `examples/personal-blog/content/posts/2026-03-05-welcome.md`
- Create: `examples/personal-blog/blog.config.json`
- Test: `Tests/IntegrationTests/GoldenBuildOutputTests.swift`

**Step 1: Write failing golden output test**

```swift
func testExampleBlogBuildMatchesGoldenOutput() throws {
    let output = try buildExampleBlog()
    let golden = try loadGolden("example-blog")
    XCTAssertEqual(normalize(output), normalize(golden))
}
```

**Step 2: Run test to verify failure**

Run: `swift test --filter GoldenBuildOutputTests`
Expected: FAIL until fixtures are finalized.

**Step 3: Implement CI + docs + fixture updates**

**Step 4: Re-run full suite**

Run: `swift test`
Expected: PASS all tests.

**Step 5: Commit**

```bash
git add .github README.md docs examples Tests/IntegrationTests
git commit -m "chore: add ci docs and golden fixtures for v1 readiness"
```

## Final Verification Checklist
- [ ] `swift test` passes.
- [ ] `swift run blog init` creates project scaffold.
- [ ] `swift run blog post new "Hello World"` creates markdown with valid front matter.
- [ ] `swift run blog build` writes static site into `docs/`.
- [ ] `swift run blog check` detects intentionally broken links in fixture.
- [ ] Generated sample page renders GFM table/task-list/strikethrough and highlighted code block.

## Notes for Execution
- Keep every task small; do not batch multiple tasks into one commit.
- Prefer fixture-driven and golden-file tests for renderer stability.
- Avoid adding non-v1 scope (search, remote plugin registry, CMS UI).

Plan complete and saved to `docs/plans/2026-03-05-swift-static-blog-implementation-plan.md`. Two execution options:

1. Subagent-Driven (this session) - I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. Parallel Session (separate) - Open a new session with executing-plans, batch execution with checkpoints.
