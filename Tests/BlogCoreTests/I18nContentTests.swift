import Foundation
import XCTest
@testable import BlogCore

final class I18nContentTests: XCTestCase {
    func testParsesLanguageSuffixFromFilename() {
        XCTAssertEqual(ContentLoader.parseLanguageSuffix(from: "wolt-cart.md"), nil)
        XCTAssertEqual(ContentLoader.parseLanguageSuffix(from: "wolt-cart.ja.md"), "ja")
        XCTAssertEqual(ContentLoader.parseLanguageSuffix(from: "deep.dotted.name.md"), nil)
        XCTAssertEqual(ContentLoader.parseLanguageSuffix(from: "deep.dotted.name.ja.md"), "ja")
        XCTAssertEqual(ContentLoader.parseLanguageSuffix(from: "post.en-US.md"), "en-US")
        XCTAssertEqual(ContentLoader.parseLanguageSuffix(from: "post.fr.md"), "fr")
    }

    func testStripsLanguageSuffixToBasename() {
        XCTAssertEqual(ContentLoader.basename(stripping: "wolt-cart.md"), "wolt-cart")
        XCTAssertEqual(ContentLoader.basename(stripping: "wolt-cart.ja.md"), "wolt-cart")
        XCTAssertEqual(ContentLoader.basename(stripping: "deep.dotted.name.md"), "deep.dotted.name")
        XCTAssertEqual(ContentLoader.basename(stripping: "deep.dotted.name.ja.md"), "deep.dotted.name")
    }

    func testCollectionItemsCarryLanguageAndAvailableLanguages() throws {
        let root = makeTempProject()
        try writeFile(root, "content/posts/hello.md", """
        ---
        title: Hello
        slug: hello
        date: 2026-01-01
        ---
        Body
        """)
        try writeFile(root, "content/posts/hello.ja.md", """
        ---
        title: こんにちは
        slug: hello
        date: 2026-01-01
        ---
        本文
        """)
        try writeFile(root, "content/posts/orphan.md", """
        ---
        title: Orphan
        slug: orphan
        date: 2026-01-02
        ---
        Body only in default lang
        """)

        let configs = [CollectionConfig(id: "posts", dir: "content/posts", route: "/posts")]
        let collections = try ContentLoader().loadCollections(configs, in: root, defaultLanguage: "en", configuredLanguages: ["en", "ja"])

        let items = collections["posts"]?.items ?? []
        XCTAssertEqual(items.count, 3)

        let helloEn = items.first { $0.slug == "hello" && $0.lang == "en" }
        let helloJa = items.first { $0.slug == "hello" && $0.lang == "ja" }
        let orphan = items.first { $0.slug == "orphan" }

        XCTAssertNotNil(helloEn)
        XCTAssertNotNil(helloJa)
        XCTAssertNotNil(orphan)

        XCTAssertEqual(helloEn?.title, "Hello")
        XCTAssertEqual(helloJa?.title, "こんにちは")
        XCTAssertEqual(Set(helloEn?.availableLanguages ?? []), Set(["en", "ja"]))
        XCTAssertEqual(Set(helloJa?.availableLanguages ?? []), Set(["en", "ja"]))
        XCTAssertEqual(orphan?.lang, "en")
        XCTAssertEqual(orphan?.availableLanguages, ["en"])
    }

    func testIgnoresLanguageSuffixesNotInConfiguredLanguages() throws {
        // A foo.fr.md file should be skipped if "fr" isn't in configuredLanguages.
        let root = makeTempProject()
        try writeFile(root, "content/posts/hello.md", """
        ---
        title: Hello
        slug: hello
        date: 2026-01-01
        ---
        en body
        """)
        try writeFile(root, "content/posts/hello.fr.md", """
        ---
        title: Bonjour
        slug: hello
        date: 2026-01-01
        ---
        fr body
        """)

        let configs = [CollectionConfig(id: "posts", dir: "content/posts", route: "/posts")]
        let collections = try ContentLoader().loadCollections(configs, in: root, defaultLanguage: "en", configuredLanguages: ["en", "ja"])

        let items = collections["posts"]?.items ?? []
        XCTAssertEqual(items.count, 1, "Only the en file should load when fr isn't configured")
        XCTAssertEqual(items.first?.lang, "en")
        XCTAssertEqual(items.first?.availableLanguages, ["en"])
    }

    func testPagesCarryLanguageAndPairByCanonicalRoute() throws {
        let root = makeTempProject()
        try writeFile(root, "content/pages/about.md", """
        ---
        title: About
        ---
        en about
        """)
        try writeFile(root, "content/pages/about.ja.md", """
        ---
        title: 自己紹介
        ---
        ja about
        """)
        try writeFile(root, "content/pages/contact.md", """
        ---
        title: Contact
        ---
        en only
        """)

        let pages = try ContentLoader().loadPages(in: root, defaultLanguage: "en", configuredLanguages: ["en", "ja"])

        let aboutEn = pages.first { $0.route == "/about/" && $0.lang == "en" }
        let aboutJa = pages.first { $0.route == "/about/" && $0.lang == "ja" }
        let contact = pages.first { $0.route == "/contact/" }

        XCTAssertNotNil(aboutEn)
        XCTAssertNotNil(aboutJa)
        XCTAssertEqual(aboutEn?.title, "About")
        XCTAssertEqual(aboutJa?.title, "自己紹介")
        XCTAssertEqual(Set(aboutEn?.availableLanguages ?? []), Set(["en", "ja"]))
        XCTAssertEqual(Set(aboutJa?.availableLanguages ?? []), Set(["en", "ja"]))
        XCTAssertEqual(contact?.availableLanguages, ["en"])
    }

    private func writeFile(_ root: URL, _ relative: String, _ content: String) throws {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func makeTempProject() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }
}
