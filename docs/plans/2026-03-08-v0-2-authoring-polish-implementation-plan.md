# v0.2 Authoring Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver the highest-priority `inkwell` roadmap items and quick wins: watch mode with live reload, an archive page, richer SEO metadata, and stronger validation checks.

**Architecture:** Extend the existing build-and-preview loop instead of adding a separate development mode. Reuse `BuildPipeline`, `RouteBuilder`, and `PreviewServer` for watch-mode behavior, add archive and metadata generation at the route-rendering layer, and grow `check` from a link-only pass into a small validation suite that reuses current content/config models.

**Tech Stack:** Swift 6, Swift ArgumentParser, XCTest, Foundation file I/O, existing `BlogCore`, `BlogCLI`, `BlogPreview`, and `BlogRenderer` modules.

---

### Task 1: Add archive page generation

**Files:**
- Modify: `Sources/BlogCore/Routing/RouteBuilder.swift`
- Modify: `Tests/BlogCoreTests/BuildPipelineIntegrationTests.swift`
- Create: `Tests/BlogCoreTests/RouteBuilderTests.swift`

**Step 1: Write the failing test**

Add a route-level test that verifies an archive page is emitted and sorted newest-first.

```swift
func testBuildsArchivePageForPublishedPosts() {
    let posts = [
        makePost(title: "Second", date: "2026-03-02T00:00:00Z", slug: "second"),
        makePost(title: "First", date: "2026-03-01T00:00:00Z", slug: "first")
    ]

    let pages = RouteBuilder().buildPages(posts: posts, renderedContent: ["second": "<p>2</p>", "first": "<p>1</p>"])
    let archive = pages.first { $0.route == "/archive/" }

    XCTAssertNotNil(archive)
    XCTAssertTrue(archive?.html.contains("Archive") == true)
    XCTAssertTrue(archive?.html.contains("/posts/second/") == true)
    XCTAssertTrue(archive?.html.contains("/posts/first/") == true)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter RouteBuilderTests/testBuildsArchivePageForPublishedPosts`
Expected: FAIL because `/archive/` is not generated yet.

**Step 3: Write minimal implementation**

Update `RouteBuilder` to emit a dedicated archive page and link to it from the home page header.

```swift
pages.append(BuiltPage(route: "/archive/", html: renderArchive(posts: mapped)))
```

Implement `renderArchive(posts:)` with a simple grouped or flat chronological listing. Keep it static HTML like the existing index/taxonomy pages.

**Step 4: Add integration coverage**

Extend `testBuildWritesPostAndIndexPages()` to assert:

```swift
XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/archive/index.html").path))
```

**Step 5: Run tests to verify they pass**

Run: `swift test --filter RouteBuilderTests`
Expected: PASS

Run: `swift test --filter BuildPipelineIntegrationTests/testBuildWritesPostAndIndexPages`
Expected: PASS

**Step 6: Commit**

```bash
git add Sources/BlogCore/Routing/RouteBuilder.swift Tests/BlogCoreTests/RouteBuilderTests.swift Tests/BlogCoreTests/BuildPipelineIntegrationTests.swift
git commit -m "feat(routes): add archive page generation"
```

### Task 2: Add canonical, Open Graph, and Twitter metadata

**Files:**
- Modify: `Sources/BlogCore/Routing/RouteBuilder.swift`
- Modify: `Sources/BlogCore/BuildPipeline.swift`
- Modify: `Sources/BlogCore/Models/PostFrontMatter.swift`
- Modify: `Tests/BlogCoreTests/BuildPipelineIntegrationTests.swift`

**Step 1: Write the failing test**

Add an integration test that verifies a built post page includes canonical and social metadata.

```swift
func testBuildAddsCanonicalAndSocialMetaTags() throws {
    let temp = makeProject()
    try writeConfig(temp, baseURL: "https://example.com")
    try writePost(temp, slug: "hello-world", title: "Hello World", summary: "Summary")

    _ = try BuildPipeline().run(in: temp)

    let html = try String(contentsOf: temp.appendingPathComponent("docs/posts/hello-world/index.html"))
    XCTAssertTrue(html.contains("<link rel=\"canonical\" href=\"https://example.com/posts/hello-world/\""))
    XCTAssertTrue(html.contains("property=\"og:title\""))
    XCTAssertTrue(html.contains("name=\"twitter:card\""))
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter BuildPipelineIntegrationTests/testBuildAddsCanonicalAndSocialMetaTags`
Expected: FAIL because these tags are not emitted yet.

**Step 3: Write minimal implementation**

Thread a normalized `baseURL` into route rendering and add shared metadata helpers.

```swift
public func buildPages(posts: [PostDocument], renderedContent: [String: String], site: SiteRenderContext) -> [BuiltPage]
```

Add a small render context carrying:
- site title
- normalized base URL
- site description fallback

Honor `frontMatter.canonicalUrl` when present; otherwise compose canonical URLs from `baseURL + route`.

Emit at least these tags on index, archive, taxonomy, and post pages:
- `<link rel="canonical" ...>`
- `<meta property="og:title" ...>`
- `<meta property="og:description" ...>`
- `<meta property="og:url" ...>`
- `<meta name="twitter:card" content="summary_large_image">` when there is a cover image, else `summary`

**Step 4: Run tests to verify they pass**

Run: `swift test --filter BuildPipelineIntegrationTests/testBuildAddsCanonicalAndSocialMetaTags`
Expected: PASS

Run: `swift test --filter BuildPipelineIntegrationTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/BlogCore/Routing/RouteBuilder.swift Sources/BlogCore/BuildPipeline.swift Sources/BlogCore/Models/PostFrontMatter.swift Tests/BlogCoreTests/BuildPipelineIntegrationTests.swift
git commit -m "feat(seo): add canonical and social metadata"
```

### Task 3: Expand `inkwell check` into a validation suite

**Files:**
- Modify: `Sources/BlogCLI/Commands/CheckCommand.swift`
- Create: `Sources/BlogCore/Validation/ProjectChecker.swift`
- Create: `Sources/BlogCore/Validation/ProjectCheckResult.swift`
- Modify: `Sources/BlogCore/Validation/LinkChecker.swift`
- Modify: `Sources/BlogCore/Content/ContentLoader.swift`
- Modify: `Tests/BlogCLITests/CheckCommandTests.swift`
- Create: `Tests/BlogCoreTests/ProjectCheckerTests.swift`

**Step 1: Write the failing test**

Add validation tests for missing cover image and malformed config.

```swift
func testCheckFailsWhenCoverImageFileIsMissing() throws {
    let root = makeProjectRoot()
    try writeConfig(root)
    try writePost(root, frontMatter: """
    title: Hello
    date: 2026-03-05T00:00:00Z
    slug: hello
    coverImage: /images/missing.jpg
    """)

    let result = try ProjectChecker().check(projectRoot: root)
    XCTAssertFalse(result.isValid)
    XCTAssertTrue(result.errors.contains { $0.contains("cover image") })
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter ProjectCheckerTests`
Expected: FAIL because project-level validation does not exist yet.

**Step 3: Write minimal implementation**

Create a project checker that aggregates:
- existing broken link results from `docs/`
- front matter schema validation from content files
- missing local asset checks for `coverImage`
- malformed `blog.config.json` decode failures

Shape the result as:

```swift
public struct ProjectCheckResult {
    public let brokenLinks: [String]
    public let errors: [String]
    public var isValid: Bool { brokenLinks.isEmpty && errors.isEmpty }
}
```

Update `CheckCommand` JSON output to include `errors`.

**Step 4: Add CLI-level coverage**

Extend `CheckCommandTests` with:
- missing cover image failure
- malformed config failure
- JSON payload includes both `brokenLinks` and `errors`

**Step 5: Run tests to verify they pass**

Run: `swift test --filter ProjectCheckerTests`
Expected: PASS

Run: `swift test --filter CheckCommandTests`
Expected: PASS

**Step 6: Commit**

```bash
git add Sources/BlogCLI/Commands/CheckCommand.swift Sources/BlogCore/Validation Sources/BlogCore/Content/ContentLoader.swift Tests/BlogCLITests/CheckCommandTests.swift Tests/BlogCoreTests/ProjectCheckerTests.swift
git commit -m "feat(check): add project validation checks"
```

### Task 4: Add watch mode and live reload to preview

**Files:**
- Modify: `Sources/BlogCLI/Commands/ServeCommand.swift`
- Modify: `Sources/BlogPreview/PreviewServer.swift`
- Create: `Sources/BlogPreview/PreviewWatcher.swift`
- Create: `Sources/BlogPreview/LiveReloadScript.swift`
- Modify: `Sources/BlogCore/BuildPipeline.swift`
- Modify: `Tests/BlogPreviewTests/PreviewServerTests.swift`
- Create: `Tests/BlogPreviewTests/PreviewWatcherTests.swift`
- Create: `Tests/BlogCLITests/ServeCommandTests.swift`

**Step 1: Write the failing tests**

Add one server test that proves live reload script injection appears in served HTML when enabled.

```swift
func testInjectsLiveReloadSnippetWhenEnabled() {
    let html = PreviewServer.injectLiveReload(into: "<html><body>Hi</body></html>", port: 35729)
    XCTAssertTrue(html.contains("EventSource"))
    XCTAssertTrue(html.contains("35729"))
}
```

Add one watcher test that proves relevant file changes trigger a rebuild callback.

```swift
func testWatcherCallsOnChangeForMarkdownFile() throws {
    var fired = false
    let watcher = PreviewWatcher(root: fixtureRoot) { fired = true }
    watcher.handleChangedPath("content/posts/hello.md")
    XCTAssertTrue(fired)
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter PreviewServerTests`
Expected: FAIL because live reload injection does not exist.

Run: `swift test --filter PreviewWatcherTests`
Expected: FAIL because watcher infrastructure does not exist.

**Step 3: Write minimal implementation**

Add `--watch` to `ServeCommand` and implement this flow:

```swift
@Flag(name: .long, help: "Rebuild and reload on content changes")
var watch = false

if watch {
    _ = try BuildPipeline().run(in: root)
    let watcher = PreviewWatcher(root: root) {
        _ = try? BuildPipeline().run(in: root)
        PreviewServer.broadcastReload()
    }
    try watcher.start()
}
```

Keep v1 watch mode simple:
- watch `content/`, `themes/`, `blog.config.json`, and optionally `public/`
- rebuild whole site on change
- inject a small EventSource-based reload script into served HTML pages only
- no debounce tuning beyond a basic short delay

**Step 4: Add CLI coverage**

Add a `ServeCommandTests` case that verifies `--watch` parses and does not change the default `port` behavior.

**Step 5: Run tests to verify they pass**

Run: `swift test --filter PreviewServerTests`
Expected: PASS

Run: `swift test --filter PreviewWatcherTests`
Expected: PASS

Run: `swift test --filter ServeCommandTests`
Expected: PASS

**Step 6: Commit**

```bash
git add Sources/BlogCLI/Commands/ServeCommand.swift Sources/BlogPreview Sources/BlogCore/BuildPipeline.swift Tests/BlogPreviewTests Tests/BlogCLITests/ServeCommandTests.swift
git commit -m "feat(serve): add watch mode with live reload"
```

### Task 5: Update docs for the new authoring workflow

**Files:**
- Modify: `README.md`
- Modify: `docs/roadmap.md`
- Modify: `docs/getting-started.md`

**Step 1: Update docs**

Document:
- `inkwell serve --watch`
- archive page behavior
- SEO metadata defaults and canonical URL override
- expanded `inkwell check` validation coverage

**Step 2: Run focused verification**

Run: `swift test --filter BlogCLITests`
Expected: PASS

Run: `swift test --filter BlogCoreTests`
Expected: PASS

**Step 3: Commit**

```bash
git add README.md docs/roadmap.md docs/getting-started.md
git commit -m "docs: add v0.2 workflow and validation guidance"
```

### Task 6: Final verification

**Files:**
- Review: `Sources/BlogCLI/Commands/ServeCommand.swift`
- Review: `Sources/BlogCLI/Commands/CheckCommand.swift`
- Review: `Sources/BlogCore/Routing/RouteBuilder.swift`
- Review: `Sources/BlogPreview/PreviewServer.swift`

**Step 1: Run the full verification suite**

Run: `npm ci`
Expected: dependencies install cleanly

Run: `make verify SWIFTLINT=swiftlint`
Expected: PASS

**Step 2: Run one manual smoke workflow**

Run: `swift run inkwell init /tmp/inkwell-v02-smoke`
Expected: scaffold created

Run: `swift run inkwell serve --watch`
Expected: initial build succeeds, preview starts, and a markdown edit triggers rebuild output

**Step 3: Commit the verified batch summary if needed**

```bash
git status
```

Expected: clean working tree after the planned commits.
