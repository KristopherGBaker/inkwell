import Foundation

public struct LinkCheckResult: Equatable {
    public let brokenLinks: [String]

    public var isValid: Bool { brokenLinks.isEmpty }

    public init(brokenLinks: [String]) {
        self.brokenLinks = brokenLinks
    }
}

public struct LinkChecker {
    public init() {}

    public func check(projectRoot: URL) -> LinkCheckResult {
        check(projectRoot: projectRoot, siteConfig: SiteConfig(title: "Blog"))
    }

    public func check(projectRoot: URL, siteConfig: SiteConfig) -> LinkCheckResult {
        let docsRoot = projectRoot.appendingPathComponent(siteConfig.outputDir)
        let basePath = normalizedBasePath(from: siteConfig.baseURL)
        guard let files = try? FileManager.default.subpathsOfDirectory(atPath: docsRoot.path).filter({ $0.hasSuffix(".html") }) else {
            return LinkCheckResult(brokenLinks: [])
        }

        var broken: Set<String> = []
        for path in files {
            let fullPath = docsRoot.appendingPathComponent(path)
            guard let html = try? String(contentsOf: fullPath) else { continue }
            let links = extractInternalLinks(from: html)
            for link in links {
                let normalized = normalizedPath(from: link, basePath: basePath).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let target: URL
                if normalized.isEmpty {
                    target = docsRoot.appendingPathComponent("index.html")
                } else if normalized.contains(".") {
                    target = docsRoot.appendingPathComponent(normalized)
                } else {
                    target = docsRoot.appendingPathComponent(normalized).appendingPathComponent("index.html")
                }
                if !FileManager.default.fileExists(atPath: target.path) {
                    broken.insert(link)
                }
            }
        }
        return LinkCheckResult(brokenLinks: broken.sorted())
    }

    private func normalizedPath(from link: String, basePath: String) -> String {
        var path = String(link.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
            .split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? link

        guard basePath.isEmpty == false else {
            return path
        }

        if path == basePath {
            return "/"
        }

        if path.hasPrefix(basePath + "/") {
            path.removeFirst(basePath.count)
        }

        return path
    }

    private func normalizedBasePath(from baseURL: String) -> String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, trimmed != "/" else {
            return ""
        }

        if let components = URLComponents(string: trimmed), components.path.isEmpty == false, components.path != "/" {
            return components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        }

        let normalized = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        return normalized == "/" ? "" : normalized
    }

    private func extractInternalLinks(from html: String) -> [String] {
        let pattern = "href=\\\"(/[^\\\"]*)\\\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = html as NSString
        return regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).compactMap {
            guard $0.numberOfRanges > 1 else { return nil }
            return ns.substring(with: $0.range(at: 1))
        }
    }
}
