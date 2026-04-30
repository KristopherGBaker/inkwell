# v0.3 Content Collections + Templating Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver the v0.3 generic primitives (collections, pages, data files, site identity, nav, configurable home) on top of a Stencil-based templating migration, plus ship a second theme (`quiet`) that renders all page types. Inkwell stays generic; krisbaker.com becomes the first consumer of the new theme (cutover is out of scope for this plan — handled in the krisbaker.com repo afterward).

**Architecture:** Migrate HTML rendering out of `RouteBuilder.swift`'s inline string literals into Stencil templates owned by themes. Split today's `RouteBuilder` into a `PageContextBuilder` (route + template + context, no HTML) and a `TemplateRenderer` (Stencil-backed, theme-aware, returns `BuiltPage`). Generalize `ContentLoader` to load any declared collection, `content/pages/`, and `data/*.yml|json`. Extend `SiteConfig` with optional `author`, `nav`, `home`, and `collections` fields. Build pipeline orchestration stays in `BuildPipeline.swift`; plugin hooks unchanged; output writer unchanged.

**Tech Stack:** Swift 6, Swift ArgumentParser, [Stencil](https://github.com/stencilproject/Stencil) (new dependency), [Yams](https://github.com/jpsim/Yams) for YAML parsing (new dependency), XCTest, existing `BlogCore`, `BlogCLI`, `BlogPreview`, `BlogRenderer`, `BlogThemes`, `BlogPlugins` modules.

**Reference docs:**
- `docs/rfcs/2026-04-30-content-collections-and-templating.md` (source of truth for behavior)
- `skills/portfolio-data/` (already shipped — used by users to populate `data/*.yml`)

---

### Task 1: Templating spike — port default theme to Stencil

**Files:**
- Modify: `Package.swift` (add Stencil dependency)
- Create: `Sources/BlogThemes/TemplateRenderer.swift`
- Create: `Sources/BlogThemes/TemplateContext.swift`
- Modify: `Sources/BlogCore/Routing/RouteBuilder.swift` (rename to `PageContextBuilder.swift`; keep public `BuiltPage`)
- Create: `Sources/BlogCore/Routing/PageContextBuilder.swift`
- Modify: `Sources/BlogCore/BuildPipeline.swift`
- Create: `themes/default/templates/base.html`
- Create: `themes/default/templates/partials/head.html`
- Create: `themes/default/templates/partials/top-bar.html`
- Create: `themes/default/templates/partials/footer.html`
- Create: `themes/default/templates/partials/taxonomy-chips.html`
- Create: `themes/default/templates/layouts/landing.html` (paginated post list — current home behavior)
- Create: `themes/default/templates/layouts/post.html`
- Create: `themes/default/templates/layouts/post-list.html` (archive)
- Create: `themes/default/templates/layouts/taxonomy.html`
- Create: `themes/default/templates/layouts/404.html`
- Create: `Tests/BlogThemesTests/TemplateRendererTests.swift`
- Modify: `Tests/BlogCoreTests/RouteBuilderTests.swift` (port to context-level assertions; rename file)

**Step 1: Write the failing tests**

A `TemplateRenderer` test:

```swift
func testRendersTemplateWithContext() throws {
    let renderer = TemplateRenderer(theme: defaultTheme)
    let html = try renderer.render(template: "post", context: [
        "site": ["title": "Field Notes"],
        "page": ["title": "Hello", "content": "<p>hi</p>"]
    ])
    XCTAssertTrue(html.contains("Hello"))
    XCTAssertTrue(html.contains("<p>hi</p>"))
}
```

A `PageContextBuilder` test (replaces direct HTML assertions):

```swift
func testEmitsPostPagePlanWithSlugRoute() {
    let posts = [makePost(slug: "hello", title: "Hello")]
    let plans = PageContextBuilder().buildPlans(posts: posts, renderedContent: ["hello": "<p>hi</p>"], siteConfig: testConfig)
    let post = plans.first { $0.route == "/posts/hello/" }
    XCTAssertEqual(post?.template, "post")
    XCTAssertEqual(post?.context["page.title"] as? String, "Hello")
}
```

A snapshot-style integration test asserting end-to-end rendered output for the default theme stays visually equivalent (allow whitespace/attribute-order differences, assert presence of canonical structural anchors):

```swift
func testDefaultThemeRendersIndexWithExpectedAnchors() throws {
    let temp = makeFixtureProject()
    _ = try BuildPipeline().run(in: temp)
    let html = try String(contentsOf: temp.appendingPathComponent("docs/index.html"))
    XCTAssertTrue(html.contains("<title>Field Notes</title>"))
    XCTAssertTrue(html.contains("rel=\"canonical\""))
    XCTAssertTrue(html.contains("/posts/hello-world/"))
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter TemplateRendererTests`
Expected: FAIL (renderer doesn't exist).

Run: `swift test --filter PageContextBuilderTests`
Expected: FAIL.

**Step 3: Write minimal implementation**

Add Stencil to `Package.swift`:

```swift
.package(url: "https://github.com/stencilproject/Stencil.git", from: "0.15.1")
```

Add to `BlogThemes` target dependencies. Add to `BlogCore` target dependencies (for the renderer integration).

Implement `TemplateRenderer`:

```swift
public struct TemplateRenderer {
    private let environment: Environment

    public init(theme: ThemeManifest) throws {
        let loader = FileSystemLoader(paths: [
            Path(theme.templatesDirectory.path),
            Path(theme.templatesDirectory.appendingPathComponent("layouts").path),
            Path(theme.templatesDirectory.appendingPathComponent("partials").path),
        ])
        self.environment = Environment(loader: loader)
    }

    public func render(template: String, context: [String: Any]) throws -> String {
        try environment.renderTemplate(name: "\(template).html", context: context)
    }
}
```

Implement `PageContextBuilder` mirroring `RouteBuilder.buildPages` but emitting plans `(route, template, context)` instead of HTML. Port each render function in `RouteBuilder.swift` into a corresponding `themes/default/templates/layouts/*.html` file. Translate Swift string interpolation to Stencil tags; preserve class names, structure, and Tailwind utility output verbatim.

Update `BuildPipeline.run`:

```swift
let plans = PageContextBuilder().buildPlans(...)
let renderer = try TemplateRenderer(theme: themes.activeTheme(for: siteConfig))
let pages = try plans.map { plan in
    BuiltPage(route: plan.route, html: try renderer.render(template: plan.template, context: plan.context))
}
```

Keep `themes.injectHeadAssets`, `writePages`, etc. unchanged.

**Step 4: Run tests to verify they pass**

Run: `swift test --filter BlogThemesTests`
Expected: PASS.

Run: `swift test --filter BlogCoreTests`
Expected: PASS.

**Step 5: Manual visual verification**

Run: `swift run inkwell init /tmp/inkwell-v03-spike && swift run inkwell post new --root /tmp/inkwell-v03-spike "Hello World" && swift run inkwell build --root /tmp/inkwell-v03-spike`

Open `/tmp/inkwell-v03-spike/docs/index.html` in a browser. Visually confirm: layout, typography, search box, archive link, pagination, post page, taxonomy pages all render unchanged from pre-spike inkwell.

**Step 6: Commit**

```bash
git add Package.swift Package.resolved Sources/BlogThemes Sources/BlogCore themes/default/templates Tests/BlogThemesTests Tests/BlogCoreTests
git commit -m "feat(themes): migrate default theme to stencil templates"
```

---

### Task 2: Extend `SiteConfig` with author, nav, home, collections

**Files:**
- Modify: `Sources/BlogCore/Models/SiteConfig.swift`
- Create: `Sources/BlogCore/Models/AuthorConfig.swift`
- Create: `Sources/BlogCore/Models/CollectionConfig.swift`
- Create: `Sources/BlogCore/Models/HomeConfig.swift`
- Create: `Sources/BlogCore/Models/NavConfig.swift`
- Modify: `Tests/BlogCoreTests/SiteConfigTests.swift` (create if absent)

**Step 1: Write the failing test**

```swift
func testDecodesAuthorAndNavAndCollectionsAndHome() throws {
    let json = """
    {
      "title": "Kris",
      "baseURL": "https://krisbaker.com/",
      "author": {
        "name": "Kristopher Baker",
        "role": "Senior Software Engineer",
        "social": [{ "label": "GitHub", "url": "https://github.com/x" }]
      },
      "nav": [{ "label": "Work", "route": "/work/" }],
      "collections": [
        { "id": "projects", "dir": "content/projects", "route": "/work", "sortBy": "year", "sortOrder": "desc", "taxonomies": ["tags"] }
      ],
      "home": { "template": "landing", "featuredCollection": "projects", "featuredCount": 4 }
    }
    """
    let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
    XCTAssertEqual(config.author?.name, "Kristopher Baker")
    XCTAssertEqual(config.collections?.first?.id, "projects")
    XCTAssertEqual(config.home?.featuredCollection, "projects")
}

func testDecodesLegacyConfigWithoutNewFields() throws {
    let json = #"{"title":"Field Notes","baseURL":"/"}"#
    let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
    XCTAssertNil(config.author)
    XCTAssertNil(config.collections)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter SiteConfigTests`
Expected: FAIL (new fields don't exist).

**Step 3: Write minimal implementation**

Add new structs:

```swift
public struct AuthorConfig: Codable, Equatable {
    public var name: String
    public var role: String?
    public var location: String?
    public var email: String?
    public var social: [SocialLink]?
}

public struct SocialLink: Codable, Equatable {
    public var label: String
    public var url: String
}

public struct CollectionConfig: Codable, Equatable {
    public var id: String
    public var dir: String
    public var route: String
    public var sortBy: String?      // defaults to "date"
    public var sortOrder: String?   // defaults to "desc"
    public var taxonomies: [String]? // defaults to ["tags", "categories"]
    public var paginate: Int?
    public var listTemplate: String?
    public var detailTemplate: String?
    public var scaffold: String?    // path to front-matter template for `content new`
}

public struct NavItem: Codable, Equatable {
    public var label: String
    public var route: String
}

public struct HomeConfig: Codable, Equatable {
    public var template: String
    public var featuredCollection: String?
    public var featuredCount: Int?
    public var recentCollection: String?
    public var recentCount: Int?
}
```

Extend `SiteConfig` with optional `author`, `nav: [NavItem]?`, `collections: [CollectionConfig]?`, `home: HomeConfig?`. All optional, all backward-compatible.

**Step 4: Run tests to verify they pass**

Run: `swift test --filter SiteConfigTests`
Expected: PASS.

Run: `swift test --filter BuildPipelineIntegrationTests`
Expected: PASS (legacy configs still decode).

**Step 5: Commit**

```bash
git add Sources/BlogCore/Models Tests/BlogCoreTests/SiteConfigTests.swift
git commit -m "feat(config): add author, nav, collections, home"
```

---

### Task 3: Add data files loader

**Files:**
- Modify: `Package.swift` (add Yams dependency)
- Create: `Sources/BlogCore/Content/DataLoader.swift`
- Create: `Tests/BlogCoreTests/DataLoaderTests.swift`
- Modify: `Sources/BlogCore/BuildPipeline.swift` (load data, pass into context)

**Step 1: Write the failing test**

```swift
func testLoadsYamlAndJsonFilesIntoNamespace() throws {
    let root = makeProjectRoot()
    try writeFile(root, "data/experience.yml", """
    - org: Wolt
      role: Senior Engineer
      years: 2023 — Now
    """)
    try writeFile(root, "data/site.json", """
    { "tagline": "Hello world" }
    """)

    let data = try DataLoader().load(in: root)
    let experience = data["experience"] as? [[String: Any]]
    XCTAssertEqual(experience?.first?["org"] as? String, "Wolt")
    let site = data["site"] as? [String: Any]
    XCTAssertEqual(site?["tagline"] as? String, "Hello world")
}

func testReturnsEmptyDictWhenDataDirAbsent() throws {
    let root = makeProjectRoot()
    let data = try DataLoader().load(in: root)
    XCTAssertTrue(data.isEmpty)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter DataLoaderTests`
Expected: FAIL.

**Step 3: Write minimal implementation**

Add Yams to `Package.swift`:

```swift
.package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
```

Implement `DataLoader`:

```swift
public struct DataLoader {
    public func load(in projectRoot: URL) throws -> [String: Any] {
        let dataDir = projectRoot.appendingPathComponent("data")
        guard FileManager.default.fileExists(atPath: dataDir.path) else { return [:] }
        var result: [String: Any] = [:]
        let files = try FileManager.default.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: nil)
        for url in files {
            let name = url.deletingPathExtension().lastPathComponent
            switch url.pathExtension.lowercased() {
            case "yml", "yaml":
                let text = try String(contentsOf: url, encoding: .utf8)
                result[name] = try Yams.load(yaml: text)
            case "json":
                let text = try String(contentsOf: url, encoding: .utf8)
                result[name] = try JSONSerialization.jsonObject(with: Data(text.utf8))
            default:
                continue
            }
        }
        return result
    }
}
```

Wire into `BuildPipeline.run` so `data` is in the template context.

**Step 4: Run tests to verify they pass**

Run: `swift test --filter DataLoaderTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Package.swift Package.resolved Sources/BlogCore/Content/DataLoader.swift Sources/BlogCore/BuildPipeline.swift Tests/BlogCoreTests/DataLoaderTests.swift
git commit -m "feat(content): load data/*.{yml,json} into template context"
```

---

### Task 4: Generic collections refactor

**Files:**
- Modify: `Sources/BlogCore/Content/ContentLoader.swift`
- Modify: `Sources/BlogCore/Routing/PageContextBuilder.swift`
- Modify: `Sources/BlogCore/BuildPipeline.swift`
- Create: `Sources/BlogCore/Models/CollectionItem.swift` (generic content item replacing post-specific assumptions)
- Modify: `Sources/BlogCore/Models/PostFrontMatter.swift` (broaden allowed fields, keep existing typed accessors)
- Modify: `Tests/BlogCoreTests/ContentLoaderTests.swift`
- Modify: `Tests/BlogCoreTests/PageContextBuilderTests.swift`

**Step 1: Write the failing tests**

```swift
func testLoadsMultipleCollectionsByConfig() throws {
    let root = makeProjectRoot()
    try writeFile(root, "content/posts/hello.md", "---\ntitle: Hi\nslug: hi\ndate: 2026-01-01\n---\nbody")
    try writeFile(root, "content/projects/wolt.md", "---\ntitle: Wolt\nslug: wolt\nyear: 2023\n---\nbody")
    let configs = [
        CollectionConfig(id: "posts", dir: "content/posts", route: "/posts"),
        CollectionConfig(id: "projects", dir: "content/projects", route: "/work")
    ]
    let collections = try ContentLoader().loadCollections(configs, in: root)
    XCTAssertEqual(collections["posts"]?.items.count, 1)
    XCTAssertEqual(collections["projects"]?.items.count, 1)
}

func testEmitsCollectionScopedTaxonomyRoutes() {
    // /posts/tags/swift/, not /tags/swift/
    let plans = PageContextBuilder().buildPlans(...)
    XCTAssertTrue(plans.contains { $0.route == "/posts/tags/swift/" })
    XCTAssertFalse(plans.contains { $0.route == "/tags/swift/" })
}

func testProjectsCollectionEmitsListAndDetailRoutes() {
    XCTAssertTrue(plans.contains { $0.route == "/work/" })
    XCTAssertTrue(plans.contains { $0.route == "/work/wolt/" })
}

func testFallsBackToImplicitPostsCollectionWhenConfigOmits() {
    // No `collections` in config → posts loads from content/posts implicitly
    // Today's behavior preserved.
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter ContentLoaderTests`
Expected: FAIL on multi-collection test.

Run: `swift test --filter PageContextBuilderTests`
Expected: FAIL on collection-scoped routes.

**Step 3: Write minimal implementation**

Generalize `ContentLoader`:

```swift
public func loadCollections(_ configs: [CollectionConfig], in projectRoot: URL) throws -> [String: Collection] { ... }
```

Each `Collection` carries `items: [CollectionItem]`, `config`, and is sortable per `sortBy`/`sortOrder`. `CollectionItem` is the generic `PostDocument` successor; carries a `frontMatter: [String: Any]` plus the typed fields posts already use (title, slug, date, summary, tags, categories, draft, series, canonicalUrl, coverImage). Add untyped passthrough for collection-specific fields like `year`, `org`, `metrics[]`, `shots[]`.

Refactor `PageContextBuilder` to:

1. Iterate each collection.
2. Emit list page at `<route>/` (with pagination if `paginate` set).
3. Emit detail pages at `<route>/<slug>/`.
4. Emit taxonomy pages at `<route>/<taxonomy>/<slug>/` for each declared taxonomy.
5. When `collections` is omitted, synthesize an implicit `posts` collection with today's defaults.

Update `BuildPipeline.run` accordingly. Keep RSS/sitemap generation pointed at the `posts` collection by default; document that other collections do not appear in feeds in v0.3 (defer feed-per-collection to v0.4).

**Step 4: Add integration coverage**

```swift
func testKrisBakerStyleConfigBuildsPostsAndProjects() throws {
    let temp = makeProjectWith(config: """
    {
      "title": "Kris",
      "baseURL": "https://krisbaker.com/",
      "collections": [
        { "id": "posts", "dir": "content/posts", "route": "/posts" },
        { "id": "projects", "dir": "content/projects", "route": "/work", "sortBy": "year", "taxonomies": ["tags"] }
      ]
    }
    """)
    try addPost(temp, slug: "hello")
    try addProject(temp, slug: "wolt", year: 2023)
    _ = try BuildPipeline().run(in: temp)
    XCTAssertTrue(fileExists(temp, "docs/posts/hello/index.html"))
    XCTAssertTrue(fileExists(temp, "docs/work/index.html"))
    XCTAssertTrue(fileExists(temp, "docs/work/wolt/index.html"))
}
```

**Step 5: Run tests to verify they pass**

Run: `swift test --filter BlogCoreTests`
Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/BlogCore Tests/BlogCoreTests
git commit -m "feat(content): generic collections with per-collection routing"
```

---

### Task 5: Add `content/pages/` standalone pages

**Files:**
- Modify: `Sources/BlogCore/Content/ContentLoader.swift`
- Modify: `Sources/BlogCore/Routing/PageContextBuilder.swift`
- Modify: `Sources/BlogCore/BuildPipeline.swift`
- Create: `Tests/BlogCoreTests/PagesTests.swift`

**Step 1: Write the failing test**

```swift
func testLoadsContentPagesAndEmitsRouteFromPath() throws {
    let root = makeProjectRoot()
    try writeFile(root, "content/pages/about.md", "---\ntitle: About\nlayout: page\n---\nAbout me.")
    _ = try BuildPipeline().run(in: root)
    XCTAssertTrue(fileExists(root, "docs/about/index.html"))
}

func testPageWithCustomLayoutResolvesAgainstActiveTheme() throws {
    // content/pages/resume.md with `layout: resume` → uses theme's resume.html template
    // Template body can ignore page.content and read data.experience etc.
}

func testNestedPagePathBecomesRoute() throws {
    // content/pages/now/index.md → /now/
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter PagesTests`
Expected: FAIL.

**Step 3: Write minimal implementation**

Extend `ContentLoader` with `loadPages(in:)` that walks `content/pages/` and returns `[Page]` with route derived from the relative path (strip `.md`, treat `index.md` as the directory route). Page has `frontMatter`, rendered `content`, `route`, and a resolved `layout` (default `"page"`).

Extend `PageContextBuilder` to emit one plan per page using `template = page.layout`. Pages live in the same context shape as collection items but under `page.*` keys, with no `collection.*` namespace.

**Step 4: Run tests to verify they pass**

Run: `swift test --filter PagesTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/BlogCore Tests/BlogCoreTests/PagesTests.swift
git commit -m "feat(content): add content/pages standalone pages"
```

---

### Task 6: Configurable home page

**Files:**
- Modify: `Sources/BlogCore/Routing/PageContextBuilder.swift`
- Modify: `Sources/BlogCore/BuildPipeline.swift`
- Modify: `Tests/BlogCoreTests/PageContextBuilderTests.swift`

**Step 1: Write the failing test**

```swift
func testHomeUsesLandingTemplateWhenConfigured() throws {
    let temp = makeProjectWith(config: """
    {
      "title": "Kris",
      "home": { "template": "landing", "featuredCollection": "projects", "featuredCount": 4, "recentCollection": "posts", "recentCount": 2 },
      "collections": [
        { "id": "posts", "dir": "content/posts", "route": "/posts" },
        { "id": "projects", "dir": "content/projects", "route": "/work", "sortBy": "year" }
      ]
    }
    """)
    try addPost(temp, slug: "hello")
    try addProject(temp, slug: "wolt", year: 2023)
    let plans = PageContextBuilder().buildPlans(...)
    let home = plans.first { $0.route == "/" }
    XCTAssertEqual(home?.template, "landing")
    let featured = home?.context["home.featured"] as? [[String: Any]]
    XCTAssertEqual(featured?.count, 1)
}

func testHomeFallsBackToPaginatedPostListWhenHomeOmitted() {
    // Today's behavior preserved.
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter PageContextBuilderTests`
Expected: FAIL.

**Step 3: Write minimal implementation**

In `PageContextBuilder`, when `siteConfig.home` is non-nil:

```swift
let featured = siteConfig.home.featuredCollection.flatMap { collections[$0]?.items.prefix(siteConfig.home.featuredCount ?? 4) }
let recent = siteConfig.home.recentCollection.flatMap { collections[$0]?.items.prefix(siteConfig.home.recentCount ?? 3) }
let context = baseSiteContext + ["home": ["featured": featured, "recent": recent], "page": ["type": "landing", ...]]
plans.append(PagePlan(route: "/", template: siteConfig.home.template, context: context))
```

When `home` is omitted, retain today's paginated post-list behavior (template `"landing"` in the `default` theme produces the same output it does today).

**Step 4: Run tests to verify they pass**

Run: `swift test --filter PageContextBuilderTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/BlogCore Tests/BlogCoreTests/PageContextBuilderTests.swift
git commit -m "feat(home): configurable home template with featured + recent"
```

---

### Task 7: Asset path validation in `inkwell check`

**Files:**
- Modify: `Sources/BlogCore/Validation/ProjectChecker.swift`
- Modify: `Sources/BlogCore/Validation/SchemaValidator.swift`
- Modify: `Tests/BlogCoreTests/ProjectCheckerTests.swift`

**Step 1: Write the failing test**

```swift
func testCheckRejectsRelativeAssetPathInFrontMatter() throws {
    let root = makeProjectRoot()
    try writeFile(root, "content/projects/wolt.md", """
    ---
    title: Wolt
    slug: wolt
    year: 2023
    shots: ["assets/foo.png"]
    ---
    """)
    let result = try ProjectChecker().check(projectRoot: root)
    XCTAssertFalse(result.isValid)
    XCTAssertTrue(result.errors.contains { $0.contains("relative asset path") })
}

func testCheckRejectsMissingAssetFile() throws {
    let root = makeProjectRoot()
    try writeFile(root, "content/projects/wolt.md", """
    ---
    title: Wolt
    slug: wolt
    shots: ["/assets/missing.png"]
    ---
    """)
    let result = try ProjectChecker().check(projectRoot: root)
    XCTAssertTrue(result.errors.contains { $0.contains("missing.png") })
}

func testCheckAllowsFullyQualifiedAssetURL() throws {
    // shots: ["https://cdn.example.com/foo.png"] → no error
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter ProjectCheckerTests`
Expected: FAIL.

**Step 3: Write minimal implementation**

Extend `ProjectChecker` with an asset validator that scans every front-matter field that looks like an asset path (`coverImage`, `shots`, `featuredImage`, etc. — match by field-name allowlist or by string-shape detection). For each:

- Reject `assets/...`, `./...`, `../...` (must be `/assets/...` or `https://...`).
- For `/assets/<path>`, check `static/assets/<path>` exists in the project root.
- For `https://...`, no validation (network calls are out of scope).

Surface as `ProjectCheckResult.errors`.

**Step 4: Run tests to verify they pass**

Run: `swift test --filter ProjectCheckerTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/BlogCore/Validation Tests/BlogCoreTests/ProjectCheckerTests.swift
git commit -m "feat(check): validate asset paths in front matter"
```

---

### Task 8: Add `inkwell content new <collection>` command

**Files:**
- Create: `Sources/BlogCLI/Commands/ContentNewCommand.swift`
- Modify: `Sources/BlogCLI/Commands/PostNewCommand.swift` (delegate to ContentNewCommand for `posts`)
- Modify: `Sources/BlogCLI/BlogCommand.swift` (register subcommand)
- Create: `Tests/BlogCLITests/ContentNewCommandTests.swift`
- Modify: `Tests/BlogCLITests/PostNewCommandTests.swift`
- Create: `skills/blog-cli/subskills/content-new.md`
- Modify: `skills/blog-cli/SKILL.md` (add routing entry)
- Modify: `skills/blog-cli/subskills/post-new.md` (add note)

**Step 1: Write the failing test**

```swift
func testContentNewProjectsCreatesScaffoldedFile() throws {
    let root = makeProjectWith(config: """
    {
      "title": "Kris",
      "collections": [
        { "id": "projects", "dir": "content/projects", "route": "/work", "sortBy": "year" }
      ]
    }
    """)
    try ContentNewCommand.run(root: root, collectionId: "projects", title: "Wolt Membership")
    XCTAssertTrue(fileExists(root, "content/projects/wolt-membership.md"))
    let content = try String(contentsOf: root.appendingPathComponent("content/projects/wolt-membership.md"))
    XCTAssertTrue(content.contains("title: Wolt Membership"))
    XCTAssertTrue(content.contains("slug: wolt-membership"))
    XCTAssertTrue(content.contains("year:"))
}

func testPostNewDelegatesToContentNew() throws {
    // `inkwell post new "Hello"` produces same output as `inkwell content new posts "Hello"`
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter ContentNewCommandTests`
Expected: FAIL.

**Step 3: Write minimal implementation**

Implement `ContentNewCommand`:

- Parse `<collection>` and title from args.
- Look up collection in `blog.config.json`. Error if not found.
- Resolve scaffold: collection's `scaffold` field if present, else infer from `sortBy` (`date` → date-style scaffold, `year` → year-style scaffold).
- Slugify title; write `<collection.dir>/<slug>.md` with the scaffold filled in.

Refactor `PostNewCommand` to delegate to `ContentNewCommand` with `collectionId: "posts"`.

**Step 4: Update CLI skills**

Add `skills/blog-cli/subskills/content-new.md` describing the new command. Add a one-line route entry to `skills/blog-cli/SKILL.md`. Add a "for non-post collections, use `inkwell content new`" note to `skills/blog-cli/subskills/post-new.md`.

**Step 5: Run tests to verify they pass**

Run: `swift test --filter BlogCLITests`
Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/BlogCLI Tests/BlogCLITests skills/blog-cli
git commit -m "feat(cli): add content new for arbitrary collections"
```

---

### Task 9: Author the `quiet` theme

**Files:**
- Create: `themes/quiet/theme.json`
- Create: `themes/quiet/templates/base.html`
- Create: `themes/quiet/templates/partials/head.html`
- Create: `themes/quiet/templates/partials/top-bar.html`
- Create: `themes/quiet/templates/partials/footer.html`
- Create: `themes/quiet/templates/partials/work-card.html`
- Create: `themes/quiet/templates/partials/post-list-item.html`
- Create: `themes/quiet/templates/partials/brand-pill.html`
- Create: `themes/quiet/templates/layouts/landing.html`
- Create: `themes/quiet/templates/layouts/post.html`
- Create: `themes/quiet/templates/layouts/page.html`
- Create: `themes/quiet/templates/layouts/post-list.html`
- Create: `themes/quiet/templates/layouts/work-list.html`
- Create: `themes/quiet/templates/layouts/case-study.html`
- Create: `themes/quiet/templates/layouts/resume.html`
- Create: `themes/quiet/templates/layouts/taxonomy.html`
- Create: `themes/quiet/templates/layouts/404.html`
- Create: `themes/quiet/assets/css/tokens.css` (port from prototype `tokens.css`)
- Create: `themes/quiet/assets/css/components.css` (port from prototype `extra-styles.css`)
- Create: `themes/quiet/assets/css/print.css` (résumé print styles)
- Create: `themes/quiet/assets/js/theme-toggle.js`
- Create: `themes/quiet/tailwind.config.js`
- Create: `themes/quiet/src/styles.css`
- Create: `Tests/BlogCoreTests/QuietThemeIntegrationTests.swift`

**Step 1: Write the failing tests**

```swift
func testQuietThemeRendersLandingFromConfig() throws {
    let temp = makeProjectWith(theme: "quiet", config: """
    { ..., "home": { "template": "landing", "featuredCollection": "projects", "featuredCount": 2 }, ... }
    """)
    try addProject(temp, slug: "wolt")
    _ = try BuildPipeline().run(in: temp)
    let html = try String(contentsOf: temp.appendingPathComponent("docs/index.html"))
    XCTAssertTrue(html.contains("Selected work"))
    XCTAssertTrue(html.contains("/work/wolt/"))
}

func testQuietThemeRendersResumeFromDataFiles() throws {
    let temp = makeProjectWith(theme: "quiet", ...)
    try writeFile(temp, "data/experience.yml", "- org: Wolt\n  role: SE\n  years: 2023 — Now\n  bullets: [Did stuff]")
    try writeFile(temp, "content/pages/resume.md", "---\ntitle: Résumé\nlayout: resume\n---\n")
    _ = try BuildPipeline().run(in: temp)
    let html = try String(contentsOf: temp.appendingPathComponent("docs/resume/index.html"))
    XCTAssertTrue(html.contains("Wolt"))
    XCTAssertTrue(html.contains("2023 — Now"))
}

func testQuietThemeCaseStudyShowsMetricsFromFrontMatter() throws { ... }
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter QuietThemeIntegrationTests`
Expected: FAIL (theme does not exist).

**Step 3: Write minimal implementation**

Author each template to match the prototype's "Quiet" direction (Direction A in `page-home.jsx`, `page-rest.jsx`, `components.jsx`). Translate JSX components into Stencil partials:

- `WorkCard variant="A"` → `partials/work-card.html` (single variant; no direction switch).
- `PostListItem variant="A"` → `partials/post-list-item.html`.
- `TopBar` → `partials/top-bar.html` (drives off `site.nav` and `site.author`).
- `Footer` → `partials/footer.html` (drives off `site.author.social`).

Layouts compose partials. Résumé layout reads from `data.experience`, `data.competencies`, `data.education`, and `site.author` exclusively (ignore `page.content`).

Port `tokens.css` and `extra-styles.css` from the prototype verbatim into the theme's assets directory. Set up `tailwind.config.js` if Tailwind is used (or skip Tailwind entirely if the prototype's CSS custom-property approach is sufficient). Theme load includes Fraunces / Manrope / JetBrains Mono via Google Fonts.

Print stylesheet (`assets/css/print.css`) hides nav, footer, theme-toggle, and tightens margins for the résumé page. Resume template adds `<button onclick="window.print()">Print / Save as PDF</button>`.

`theme.json`:

```json
{
  "name": "quiet",
  "version": "0.3.0",
  "templatesDirectory": "templates",
  "assetsDirectory": "assets",
  "supportedLayouts": ["landing", "post", "page", "post-list", "work-list", "case-study", "resume", "taxonomy", "404"]
}
```

**Step 4: Manual visual verification**

Build a fixture project styled like krisbaker.com with the prototype data and verify the rendered output matches the prototype's Quiet direction visually. Open `index.html`, `/work/wolt-membership/`, `/resume/`, `/posts/<existing>/`. Test print preview on the résumé.

**Step 5: Run tests to verify they pass**

Run: `swift test --filter QuietThemeIntegrationTests`
Expected: PASS.

Run: `swift test`
Expected: PASS (full suite, regression check).

**Step 6: Commit**

```bash
git add themes/quiet Tests/BlogCoreTests/QuietThemeIntegrationTests.swift
git commit -m "feat(themes): add quiet theme with portfolio + blog layouts"
```

---

### Task 10: Update docs and roadmap

**Files:**
- Modify: `README.md`
- Modify: `docs/roadmap.md`
- Modify: `docs/getting-started.md`

**Step 1: Update docs**

Document:
- Adding a second collection (`projects`) via `blog.config.json`.
- Authoring `content/pages/` and `data/*.yml`.
- `inkwell content new <collection> "Title"`.
- Selecting `theme: "quiet"` and the typography it ships.
- Asset path convention (`/assets/...`, files in `static/assets/`).
- Reference to the `portfolio-data` skill for résumé import.

Move v0.3 items from "Near-Term" to "Shipped" in `docs/roadmap.md`.

**Step 2: Run focused verification**

Run: `swift test`
Expected: PASS.

**Step 3: Commit**

```bash
git add README.md docs/roadmap.md docs/getting-started.md
git commit -m "docs: document v0.3 collections, pages, data, quiet theme"
```

---

### Task 11: Final verification

**Files:**
- Review: `Sources/BlogCore/BuildPipeline.swift`
- Review: `Sources/BlogCore/Routing/PageContextBuilder.swift`
- Review: `Sources/BlogThemes/TemplateRenderer.swift`
- Review: `themes/quiet/templates/`
- Review: `Sources/BlogCLI/Commands/ContentNewCommand.swift`

**Step 1: Run the full verification suite**

Run: `npm ci`
Expected: dependencies install cleanly.

Run: `make verify SWIFTLINT=swiftlint`
Expected: PASS.

**Step 2: Run smoke workflows**

Smoke 1 — legacy blog (zero config changes):

```bash
rm -rf /tmp/inkwell-v03-blog
swift run inkwell init /tmp/inkwell-v03-blog
swift run inkwell post new --root /tmp/inkwell-v03-blog "Hello World"
swift run inkwell build --root /tmp/inkwell-v03-blog
swift run inkwell check --root /tmp/inkwell-v03-blog
```

Expected: builds and validates clean. Output looks unchanged from v0.2 default theme.

Smoke 2 — portfolio site:

```bash
rm -rf /tmp/inkwell-v03-portfolio
swift run inkwell init /tmp/inkwell-v03-portfolio
# Manually edit blog.config.json to add `collections`, `home`, `author`, `nav`, `theme: "quiet"`
swift run inkwell content new --root /tmp/inkwell-v03-portfolio projects "Wolt Membership"
# Edit project front matter to add metrics + shots; add data/experience.yml etc.
swift run inkwell build --root /tmp/inkwell-v03-portfolio
swift run inkwell check --root /tmp/inkwell-v03-portfolio
```

Expected: portfolio renders with quiet theme. Landing, work index, case study, résumé, post detail all reachable. Asset validation surfaces missing image references.

**Step 3: Confirm clean tree**

```bash
git status
```

Expected: clean working tree after the planned commits.

---

## Out of scope for this plan

- **krisbaker.com cutover.** Authoring project markdown, populating `data/*.yml`, switching theme — happens in `~/code/github/KristopherGBaker/krisbaker.com` after v0.3 ships in inkwell. Use the `portfolio-data` skill to import the résumé.
- **Cross-collection aggregate taxonomy views.** Deferred to v0.4.
- **RSS / sitemap per collection.** Deferred. v0.3 keeps feeds posts-only.
- **Image pipeline, scheduled publishing, redirects, multi-language.** Separate roadmap items.
- **Replacing the existing default theme's typography.** It stays unchanged.
