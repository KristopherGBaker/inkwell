import Foundation

/// Closure handed to `PageContextBuilder` so it can resolve a front-matter
/// image path (e.g. `/static/cover.png`) into a Stencil-friendly dict
/// containing `src`, `srcset`, `srcsetAvif`, `sizes`, `width`, `height`, `alt`.
/// Returns `nil` to fall through to the basic `{src, alt}` shape.
public typealias FrontMatterImageResolver = (_ path: String, _ alt: String) -> [String: Any]?

/// Closure handed to `PageContextBuilder` so it can request a generated OG
/// card URL for a page. Receives the page's translated title, subtitle, and
/// language tag. Returns the absolute or basePath-relative URL of the card
/// (e.g. `/og/abc123.png`), or `nil` if generation is unavailable.
public typealias OGCardURLResolver = (_ title: String, _ subtitle: String, _ lang: String) -> String?

/// Resolved variant set for a single image — what templates need to render
/// a `<picture>` block from front-matter (e.g. `coverImage: /static/foo.png`).
///
/// `srcset` carries the webp-or-passthrough widths; `srcsetAvif` the avif
/// widths. `sizes` defaults to `"100vw"` when the resolver can't infer a
/// better hint — themes can override per-template via Stencil. Dimensions
/// are the source's intrinsic width/height for layout stability.
public struct ResponsiveImage: Equatable, Sendable {
    public let src: String
    public let srcset: String
    public let srcsetAvif: String
    public let sizes: String
    public let width: Int
    public let height: Int
    public let alt: String

    public init(
        src: String,
        srcset: String,
        srcsetAvif: String,
        sizes: String,
        width: Int,
        height: Int,
        alt: String
    ) {
        self.src = src
        self.srcset = srcset
        self.srcsetAvif = srcsetAvif
        self.sizes = sizes
        self.width = width
        self.height = height
        self.alt = alt
    }

    public func contextDict() -> [String: Any] {
        [
            "src": src,
            "srcset": srcset,
            "srcsetAvif": srcsetAvif,
            "sizes": sizes,
            "width": width,
            "height": height,
            "alt": alt
        ]
    }
}

/// Resolves a front-matter image path (typically rooted at `/static/...` or
/// `/public/...`) into a `ResponsiveImage` by shelling variant generation out
/// to `ImageVariantGenerator`. Tracks the variant filenames it has handed
/// out so the build pipeline can copy just those into the output dir.
public final class ResponsiveImageResolver {
    private let projectRoot: URL
    private let generator: ImageVariantGenerator
    private let spec: ImageVariantSpec
    private let urlPrefix: String
    private let defaultSizes: String
    private var used: Set<String> = []

    public init(
        projectRoot: URL,
        generator: ImageVariantGenerator? = nil,
        spec: ImageVariantSpec = .defaults,
        urlPrefix: String = "/_processed/",
        defaultSizes: String = "100vw"
    ) {
        self.projectRoot = projectRoot
        self.generator = generator ?? ImageVariantGenerator(projectRoot: projectRoot)
        self.spec = spec
        self.urlPrefix = urlPrefix
        self.defaultSizes = defaultSizes
    }

    public var usedVariantFilenames: Set<String> { used }

    public func resolve(path: String, alt: String) -> ResponsiveImage? {
        guard let sourceURL = ImageAssetPathResolver.projectURL(forSource: path, projectRoot: projectRoot) else {
            return nil
        }
        if path.contains("/raw/") { return nil }
        guard let result = generator.ensureVariants(source: sourceURL, spec: spec) else {
            return nil
        }
        if result.metadata.bypassed {
            return ResponsiveImage(
                src: path,
                srcset: "",
                srcsetAvif: "",
                sizes: defaultSizes,
                width: result.metadata.width,
                height: result.metadata.height,
                alt: alt
            )
        }
        let avif = result.variants.filter { $0.format == "avif" }.sorted { $0.width < $1.width }
        let webp = result.variants.filter { $0.format == "webp" }.sorted { $0.width < $1.width }
        let other = result.variants.filter { $0.format != "avif" && $0.format != "webp" }.sorted { $0.width < $1.width }
        let fallback = webp.last ?? other.last ?? avif.last
        guard let fallback else { return nil }
        used.formUnion(result.variants.map(\.filename))
        return ResponsiveImage(
            src: "\(urlPrefix)\(fallback.filename)",
            srcset: ResponsiveImageMarkup.srcset(webp, urlPrefix: urlPrefix),
            srcsetAvif: ResponsiveImageMarkup.srcset(avif, urlPrefix: urlPrefix),
            sizes: defaultSizes,
            width: result.metadata.width,
            height: result.metadata.height,
            alt: alt
        )
    }
}

enum ResponsiveImageMarkup {
    static func srcset(_ variants: [ImageVariant], urlPrefix: String) -> String {
        variants.map { "\(urlPrefix)\($0.filename) \($0.width)w" }.joined(separator: ", ")
    }
}

enum ImageAssetPathResolver {
    static func projectURL(forSource src: String, projectRoot: URL) -> URL? {
        let trimmed = src.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("://") || trimmed.hasPrefix("data:") || trimmed.hasPrefix("mailto:") || trimmed.hasPrefix("tel:") {
            return nil
        }
        guard trimmed.hasPrefix("/") else { return nil }
        let stripped = String(trimmed.dropFirst())
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
}
