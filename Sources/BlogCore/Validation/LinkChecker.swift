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
        let docsRoot = projectRoot.appendingPathComponent("docs")
        guard let files = try? FileManager.default.subpathsOfDirectory(atPath: docsRoot.path).filter({ $0.hasSuffix(".html") }) else {
            return LinkCheckResult(brokenLinks: [])
        }

        var broken: [String] = []
        for path in files {
            let fullPath = docsRoot.appendingPathComponent(path)
            guard let html = try? String(contentsOf: fullPath) else { continue }
            let links = extractInternalLinks(from: html)
            for link in links {
                let normalized = link.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let target: URL
                if normalized.isEmpty {
                    target = docsRoot.appendingPathComponent("index.html")
                } else if normalized.contains(".") {
                    target = docsRoot.appendingPathComponent(normalized)
                } else {
                    target = docsRoot.appendingPathComponent(normalized).appendingPathComponent("index.html")
                }
                if !FileManager.default.fileExists(atPath: target.path) {
                    broken.append(link)
                }
            }
        }
        return LinkCheckResult(brokenLinks: broken.sorted())
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
