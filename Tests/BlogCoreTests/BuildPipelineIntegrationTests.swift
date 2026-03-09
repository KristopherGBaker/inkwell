import Foundation
import XCTest
@testable import BlogCore
import BlogPlugins

final class BuildPipelineIntegrationTests: XCTestCase {
    func testBuildWritesPostAndIndexPages() throws {
        let temp = try makeTempBlogProject()

        let post = """
        ---
        title: Hello World
        date: 2026-03-05T00:00:00Z
        slug: hello-world
        tags: [swift, logs]
        categories: [engineering]
        ---

        Test post body
        """
        try post.write(to: temp.appendingPathComponent("content/posts/2026-03-05-hello-world.md"), atomically: true, encoding: .utf8)

        let report = try BuildPipeline().run(in: temp)
        XCTAssertEqual(report.errors.count, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/index.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/archive/index.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/posts/hello-world/index.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/tags/swift/index.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/categories/engineering/index.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/sitemap.xml").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/robots.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/rss.xml").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/search-index.json").path))

        let indexHTML = try String(contentsOf: temp.appendingPathComponent("docs/index.html"))
        XCTAssertTrue(indexHTML.contains("/posts/hello-world/"))
        XCTAssertTrue(indexHTML.contains("href=\"/archive/\""))
        XCTAssertTrue(indexHTML.contains("id=\"search-input\""))

        let archiveHTML = try String(contentsOf: temp.appendingPathComponent("docs/archive/index.html"))
        XCTAssertTrue(archiveHTML.contains("/posts/hello-world/"))

        let searchIndexJSON = try String(contentsOf: temp.appendingPathComponent("docs/search-index.json"))
        XCTAssertTrue(searchIndexJSON.contains("\"slug\" : \"hello-world\""))
    }

    func testBuildCreatesSecondPageWhenPostCountExceedsPageSize() throws {
        let temp = try makeTempBlogProject()

        for day in 1...7 {
            let date = String(format: "2026-03-%02d", day)
            let post = """
            ---
            title: Post \(day)
            date: \(date)T00:00:00Z
            slug: post-\(day)
            ---

            Body
            """
            let fileName = "\(date)-post-\(day).md"
            try post.write(to: temp.appendingPathComponent("content/posts/\(fileName)"), atomically: true, encoding: .utf8)
        }

        _ = try BuildPipeline().run(in: temp)
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.appendingPathComponent("docs/page/2/index.html").path))
    }

    func testBuildIncludesCanonicalAndSocialMetadataOnRenderedPages() throws {
        let temp = try makeTempBlogProject()

        let config = """
        {
          "title": "Custom Journal",
          "baseURL": "https://example.com/blog/",
          "theme": "default",
          "outputDir": "docs"
        }
        """
        try config.write(to: temp.appendingPathComponent("blog.config.json"), atomically: true, encoding: .utf8)

        let post = """
        ---
        title: Metadata Ready
        date: 2026-03-06T00:00:00Z
        slug: metadata-ready
        summary: Shipping metadata for modern previews.
        tags: [swift]
        categories: [engineering]
        canonicalUrl: https://canonical.example.com/posts/metadata-ready/
        coverImage: /images/cover.jpg
        ---

        Body
        """
        try post.write(to: temp.appendingPathComponent("content/posts/2026-03-06-metadata-ready.md"), atomically: true, encoding: .utf8)

        _ = try BuildPipeline().run(in: temp)

        let postHTML = try String(contentsOf: temp.appendingPathComponent("docs/posts/metadata-ready/index.html"))
        XCTAssertTrue(postHTML.contains("<link rel=\"canonical\" href=\"https://canonical.example.com/posts/metadata-ready/\""))
        XCTAssertTrue(postHTML.contains("property=\"og:title\" content=\"Metadata Ready\""))
        XCTAssertTrue(postHTML.contains("property=\"og:description\" content=\"Shipping metadata for modern previews.\""))
        XCTAssertTrue(postHTML.contains("property=\"og:url\" content=\"https://canonical.example.com/posts/metadata-ready/\""))
        XCTAssertTrue(postHTML.contains("name=\"twitter:card\" content=\"summary_large_image\""))

        let indexHTML = try String(contentsOf: temp.appendingPathComponent("docs/index.html"))
        XCTAssertTrue(indexHTML.contains("<title>Custom Journal</title>"))
        XCTAssertTrue(indexHTML.contains("<link rel=\"canonical\" href=\"https://example.com/blog/\""))
        XCTAssertTrue(indexHTML.contains("property=\"og:url\" content=\"https://example.com/blog/\""))
        XCTAssertTrue(indexHTML.contains("name=\"twitter:card\" content=\"summary\""))

        let archiveHTML = try String(contentsOf: temp.appendingPathComponent("docs/archive/index.html"))
        XCTAssertTrue(archiveHTML.contains("<link rel=\"canonical\" href=\"https://example.com/blog/archive/\""))
        XCTAssertTrue(archiveHTML.contains("property=\"og:url\" content=\"https://example.com/blog/archive/\""))

        let tagHTML = try String(contentsOf: temp.appendingPathComponent("docs/tags/swift/index.html"))
        XCTAssertTrue(tagHTML.contains("<link rel=\"canonical\" href=\"https://example.com/blog/tags/swift/\""))
        XCTAssertTrue(tagHTML.contains("property=\"og:url\" content=\"https://example.com/blog/tags/swift/\""))

        let categoryHTML = try String(contentsOf: temp.appendingPathComponent("docs/categories/engineering/index.html"))
        XCTAssertTrue(categoryHTML.contains("<link rel=\"canonical\" href=\"https://example.com/blog/categories/engineering/\""))
        XCTAssertTrue(categoryHTML.contains("property=\"og:url\" content=\"https://example.com/blog/categories/engineering/\""))
    }

    func testBuildFailsWhenDistinctTaxonomyLabelsNormalizeToSameSlug() throws {
        let temp = try makeTempBlogProject()

        let firstPost = """
        ---
        title: First
        date: 2026-03-07T00:00:00Z
        slug: first
        tags: [Swift]
        ---

        Body
        """
        try firstPost.write(to: temp.appendingPathComponent("content/posts/2026-03-07-first.md"), atomically: true, encoding: .utf8)

        let secondPost = """
        ---
        title: Second
        date: 2026-03-08T00:00:00Z
        slug: second
        tags: [swift!]
        ---

        Body
        """
        try secondPost.write(to: temp.appendingPathComponent("content/posts/2026-03-08-second.md"), atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try BuildPipeline().run(in: temp)) { error in
            XCTAssertEqual(error as? BuildPipelineError, .taxonomySlugCollision(kind: "tags", slug: "swift", labels: ["Swift", "swift!"]))
        }
    }

    func testBuildPassesDocsRelativeOutputPathsToAfterRenderPlugins() throws {
        let temp = try makeTempBlogProject()

        let post = """
        ---
        title: Hook Target
        date: 2026-03-07T00:00:00Z
        slug: hook-target
        ---

        Body
        """
        try post.write(to: temp.appendingPathComponent("content/posts/2026-03-07-hook-target.md"), atomically: true, encoding: .utf8)

        let plugin = RecordingAfterRenderPlugin()
        let pipeline = BuildPipeline(plugins: PluginManager(plugins: [plugin]))

        _ = try pipeline.run(in: temp)

        XCTAssertEqual(
            plugin.outputPaths,
            [
                "docs/index.html",
                "docs/archive/index.html",
                "docs/posts/hook-target/index.html"
            ]
        )
    }

    func testBuildPassesNestedOutputDirPathsToAfterRenderPlugins() throws {
        let temp = try makeTempBlogProject()

        let config = """
        {
          "title": "Field Notes",
          "baseURL": "https://example.com/blog/",
          "theme": "default",
          "outputDir": "public/site"
        }
        """
        try config.write(to: temp.appendingPathComponent("blog.config.json"), atomically: true, encoding: .utf8)

        let post = """
        ---
        title: Nested Hook Target
        date: 2026-03-07T00:00:00Z
        slug: nested-hook-target
        ---

        Body
        """
        try post.write(to: temp.appendingPathComponent("content/posts/2026-03-07-nested-hook-target.md"), atomically: true, encoding: .utf8)

        let plugin = RecordingAfterRenderPlugin()
        let pipeline = BuildPipeline(plugins: PluginManager(plugins: [plugin]))

        _ = try pipeline.run(in: temp)

        XCTAssertEqual(
            plugin.outputPaths,
            [
                "public/site/index.html",
                "public/site/archive/index.html",
                "public/site/posts/nested-hook-target/index.html"
            ]
        )
    }

    func testBuildEscapesFrontMatterDerivedHTMLInRenderedRoutes() throws {
        let temp = try makeTempBlogProject()

        let post = """
        ---
        title: 'Rock < Roll & "Quotes"'
        date: 2026-03-08T00:00:00Z
        slug: escaping-check
        summary: 'Use <tags> & "quotes" safely'
        tags: ["dev <tools>"]
        categories: ["research & development"]
        coverImage: '/images/cover?caption=<unsafe>&name="hero"'
        ---

        Body
        """
        try post.write(to: temp.appendingPathComponent("content/posts/2026-03-08-escaping-check.md"), atomically: true, encoding: .utf8)

        _ = try BuildPipeline().run(in: temp)

        let postHTML = try String(contentsOf: temp.appendingPathComponent("docs/posts/escaping-check/index.html"))
        XCTAssertTrue(postHTML.contains("<title>Rock &lt; Roll &amp; &quot;Quotes&quot;</title>"))
        XCTAssertTrue(postHTML.contains("content=\"Use &lt;tags&gt; &amp; &quot;quotes&quot; safely\""))
        XCTAssertTrue(postHTML.contains("alt=\"Cover image for Rock &lt; Roll &amp; &quot;Quotes&quot;\""))
        XCTAssertTrue(postHTML.contains("src=\"/images/cover?caption=&lt;unsafe&gt;&amp;name=&quot;hero&quot;\""))
        XCTAssertTrue(postHTML.contains(">dev &lt;tools&gt;</a>"))
        XCTAssertTrue(postHTML.contains(">research &amp; development</a>"))
        XCTAssertFalse(postHTML.contains("<h1 class=\"mt-3 font-display text-4xl leading-tight text-stone-900 dark:text-stone-100 md:text-5xl\">Rock < Roll & \"Quotes\"</h1>"))

        let indexHTML = try String(contentsOf: temp.appendingPathComponent("docs/index.html"))
        XCTAssertTrue(indexHTML.contains(">Rock &lt; Roll &amp; &quot;Quotes&quot;</a>"))
        XCTAssertTrue(indexHTML.contains(">Use &lt;tags&gt; &amp; &quot;quotes&quot; safely</p>"))

        let tagHTML = try String(contentsOf: temp.appendingPathComponent("docs/tags/dev-tools/index.html"))
        XCTAssertTrue(tagHTML.contains("<title>Tags: dev &lt;tools&gt;</title>"))
        XCTAssertTrue(tagHTML.contains(">Tags: dev &lt;tools&gt;</h1>"))
    }
}
