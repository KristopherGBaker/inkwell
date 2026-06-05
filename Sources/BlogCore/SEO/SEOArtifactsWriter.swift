import Foundation

/// Renders and writes the sitemap, robots.txt, and RSS feed(s) for a build.
/// Extracted from `BuildPipeline` so the pipeline file stays focused on
/// orchestration and so feed/sitemap rendering is independently testable.
struct SEOArtifactsWriter {
    let writer: OutputWriter

    // swiftlint:disable:next function_parameter_count
    func writeAll(
        posts: [PostDocument],
        collections: [String: Collection],
        postRenderedContent: [String: String],
        collectionRenderedContent: [String: [String: [String: String]]],
        routes: [String],
        outputRoot: URL,
        siteConfig: SiteConfig,
        urlBuilder: SiteURLBuilder
    ) throws {
        let defaultLanguage = siteConfig.i18n?.resolvedDefaultLanguage ?? "en"
        let configuredLanguages = siteConfig.i18n?.resolvedLanguages ?? [defaultLanguage]
        let i18nEnabled = siteConfig.i18n != nil && configuredLanguages.count > 1

        let sitemap = renderSitemap(
            routes: routes,
            urlBuilder: urlBuilder,
            defaultLanguage: defaultLanguage,
            configuredLanguages: configuredLanguages,
            i18nEnabled: i18nEnabled
        )

        let robots = """
        User-agent: *
        Allow: /
        Sitemap: \(urlBuilder.compose(route: "/sitemap.xml"))
        """

        try writer.writeFile(relativePath: "sitemap.xml", content: sitemap, to: outputRoot)
        try writer.writeFile(relativePath: "robots.txt", content: robots, to: outputRoot)

        try writeFeeds(
            posts: posts,
            collections: collections,
            postRenderedContent: postRenderedContent,
            collectionRenderedContent: collectionRenderedContent,
            outputRoot: outputRoot,
            siteConfig: siteConfig,
            defaultLanguage: defaultLanguage,
            configuredLanguages: configuredLanguages,
            i18nEnabled: i18nEnabled
        )
    }

    // MARK: - Sitemap

    func renderSitemap(
        routes: [String],
        urlBuilder: SiteURLBuilder,
        defaultLanguage: String,
        configuredLanguages: [String],
        i18nEnabled: Bool
    ) -> String {
        if i18nEnabled == false {
            let entries = routes.map { route in
                "  <url><loc>\(xmlEscape(urlBuilder.compose(route: route)))</loc></url>"
            }.joined(separator: "\n")
            return """
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
            \(entries)
            </urlset>
            """
        }

        // /<defaultLang>/... routes are meta-refresh aliases for the
        // canonical default-language URLs. Excluding them here keeps the
        // sitemap from advertising two URLs that resolve to the same content.
        let defaultLangAliasPrefix = "/\(defaultLanguage)/"
        let filteredRoutes = routes.filter { route in
            route != "/\(defaultLanguage)" && route.hasPrefix(defaultLangAliasPrefix) == false
        }

        let nonDefaultLanguages = configuredLanguages.filter { $0 != defaultLanguage }
        let groupsByCanonical = groupRoutesByCanonical(
            filteredRoutes,
            defaultLanguage: defaultLanguage,
            nonDefaultLanguages: nonDefaultLanguages
        )

        var entries: [String] = []
        for route in filteredRoutes {
            let canonical = canonicalForm(of: route, nonDefaultLanguages: nonDefaultLanguages)
            let group = groupsByCanonical[canonical] ?? [:]
            var lines: [String] = ["  <url>"]
            lines.append("    <loc>\(xmlEscape(urlBuilder.compose(route: route)))</loc>")
            for lang in configuredLanguages {
                guard let altRoute = group[lang] else { continue }
                lines.append(
                    "    <xhtml:link rel=\"alternate\" hreflang=\"\(lang)\" "
                    + "href=\"\(xmlEscape(urlBuilder.compose(route: altRoute)))\"/>"
                )
            }
            if let defaultRoute = group[defaultLanguage] {
                lines.append(
                    "    <xhtml:link rel=\"alternate\" hreflang=\"x-default\" "
                    + "href=\"\(xmlEscape(urlBuilder.compose(route: defaultRoute)))\"/>"
                )
            }
            lines.append("  </url>")
            entries.append(lines.joined(separator: "\n"))
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
        \(entries.joined(separator: "\n"))
        </urlset>
        """
    }

    private func groupRoutesByCanonical(
        _ routes: [String],
        defaultLanguage: String,
        nonDefaultLanguages: [String]
    ) -> [String: [String: String]] {
        var groups: [String: [String: String]] = [:]
        for route in routes {
            let canonical = canonicalForm(of: route, nonDefaultLanguages: nonDefaultLanguages)
            let lang = languagePrefix(of: route, nonDefaultLanguages: nonDefaultLanguages) ?? defaultLanguage
            groups[canonical, default: [:]][lang] = route
        }
        return groups
    }

    private func canonicalForm(of route: String, nonDefaultLanguages: [String]) -> String {
        for lang in nonDefaultLanguages {
            let prefix = "/\(lang)"
            if route == prefix { return "/" }
            if route.hasPrefix(prefix + "/") { return String(route.dropFirst(prefix.count)) }
        }
        return route
    }

    private func languagePrefix(of route: String, nonDefaultLanguages: [String]) -> String? {
        for lang in nonDefaultLanguages {
            let prefix = "/\(lang)"
            if route == prefix || route.hasPrefix(prefix + "/") { return lang }
        }
        return nil
    }
}

/// XML-escapes the five characters that need escaping in attribute and text
/// content. Public-internal so other build artifacts (e.g. search index XML
/// shapes, future feed formats) can reuse the same escaping rules.
func xmlEscape(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}
