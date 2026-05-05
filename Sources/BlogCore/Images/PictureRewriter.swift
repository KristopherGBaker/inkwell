import Foundation

/// Post-render HTML pass: turns each `<img src="/<asset>">` that resolves to a
/// project asset into a `<picture>` block referencing cached responsive
/// variants. Sources outside `static/` and `public/`, anything under
/// `static/raw/`, external URLs, and data URIs all pass through untouched.
///
/// Composes after `AssetURLRewriter` (so img URLs are already absolute paths)
/// and before theme head injection.
public struct PictureRewriter {
    public struct Result: Equatable {
        public let html: String
        public let usedVariantFilenames: Set<String>
    }

    private let projectRoot: URL
    private let generator: ImageVariantGenerator
    private let spec: ImageVariantSpec
    private let urlPrefix: String

    public init(
        projectRoot: URL,
        generator: ImageVariantGenerator? = nil,
        spec: ImageVariantSpec = .defaults,
        urlPrefix: String = "/_processed/"
    ) {
        self.projectRoot = projectRoot
        self.generator = generator ?? ImageVariantGenerator(projectRoot: projectRoot)
        self.spec = spec
        self.urlPrefix = urlPrefix
    }

    public func rewrite(html: String) -> Result {
        let pattern = "<img\\s[^>]*?>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return Result(html: html, usedVariantFilenames: [])
        }
        let nsHTML = html as NSString
        var output = ""
        var cursor = 0
        var used: Set<String> = []

        regex.enumerateMatches(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length)) { match, _, _ in
            guard let match else { return }
            output += nsHTML.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let original = nsHTML.substring(with: match.range)
            let (replacement, variants) = transform(imgTag: original)
            output += replacement
            used.formUnion(variants)
            cursor = match.range.location + match.range.length
        }
        if cursor < nsHTML.length {
            output += nsHTML.substring(from: cursor)
        }
        return Result(html: output, usedVariantFilenames: used)
    }

    // MARK: - per-tag transform

    private func transform(imgTag: String) -> (String, Set<String>) {
        guard let src = attribute("src", in: imgTag) else { return (imgTag, []) }
        if src.contains("/raw/") { return (imgTag, []) }
        guard let sourceURL = resolveProjectPath(src) else { return (imgTag, []) }
        guard let result = generator.ensureVariants(source: sourceURL, spec: spec) else {
            return (imgTag, [])
        }
        let alt = attribute("alt", in: imgTag) ?? ""
        let title = attribute("title", in: imgTag)
        if result.metadata.bypassed {
            return (renderBypass(src: src, alt: alt, title: title, metadata: result.metadata), [])
        }
        let markup = renderPicture(alt: alt, title: title, result: result)
        return (markup, Set(result.variants.map(\.filename)))
    }

    private func renderPicture(alt: String, title: String?, result: ImageVariantResult) -> String {
        let avif = result.variants.filter { $0.format == "avif" }.sorted { $0.width < $1.width }
        let webp = result.variants.filter { $0.format == "webp" }.sorted { $0.width < $1.width }
        let other = result.variants.filter { $0.format != "avif" && $0.format != "webp" }.sorted { $0.width < $1.width }

        var parts: [String] = ["<picture>"]
        if !avif.isEmpty {
            parts.append("<source type=\"image/avif\" srcset=\"\(srcset(avif))\">")
        }
        if !webp.isEmpty {
            parts.append("<source type=\"image/webp\" srcset=\"\(srcset(webp))\">")
        }
        let fallback = webp.last ?? other.last ?? avif.last
        guard let fallback else { return "<picture></picture>" }
        var img = "<img src=\"\(urlPrefix)\(fallback.filename)\""
        img += attrPair("alt", alt)
        if let title { img += attrPair("title", title) }
        if result.metadata.width > 0 && result.metadata.height > 0 {
            img += " width=\"\(result.metadata.width)\" height=\"\(result.metadata.height)\""
        }
        img += " loading=\"lazy\" decoding=\"async\">"
        parts.append(img)
        parts.append("</picture>")
        return parts.joined()
    }

    private func renderBypass(src: String, alt: String, title: String?, metadata: ImageMetadata) -> String {
        var img = "<img src=\"\(src)\""
        img += attrPair("alt", alt)
        if let title { img += attrPair("title", title) }
        if metadata.width > 0 && metadata.height > 0 {
            img += " width=\"\(metadata.width)\" height=\"\(metadata.height)\""
        }
        img += " loading=\"lazy\" decoding=\"async\">"
        return img
    }

    private func srcset(_ variants: [ImageVariant]) -> String {
        variants.map { "\(urlPrefix)\($0.filename) \($0.width)w" }.joined(separator: ", ")
    }

    private func attrPair(_ name: String, _ value: String) -> String {
        " \(name)=\"\(escapeAttribute(value))\""
    }

    // MARK: - parsing helpers

    private func attribute(_ name: String, in tag: String) -> String? {
        let pattern = "\\s\(name)\\s*=\\s*\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsTag = tag as NSString
        guard let match = regex.firstMatch(in: tag, options: [], range: NSRange(location: 0, length: nsTag.length)) else {
            return nil
        }
        return nsTag.substring(with: match.range(at: 1))
    }

    private func resolveProjectPath(_ src: String) -> URL? {
        if src.contains("://") || src.hasPrefix("data:") || src.hasPrefix("mailto:") || src.hasPrefix("tel:") {
            return nil
        }
        guard src.hasPrefix("/") else { return nil }
        let stripped = String(src.dropFirst())
        let candidate = projectRoot.appendingPathComponent(stripped)
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        for root in ["static", "public"] where stripped.hasPrefix(root + "/") == false {
            let alt = projectRoot.appendingPathComponent(root).appendingPathComponent(stripped)
            if FileManager.default.fileExists(atPath: alt.path) {
                return alt
            }
        }
        return nil
    }

    private func escapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
