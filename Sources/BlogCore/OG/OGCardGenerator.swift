import BlogRenderer
import CryptoKit
import Foundation

public struct OGCardSpec: Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public let author: String
    public let lang: String
    public let theme: String
    public let accent: String

    public init(
        title: String,
        subtitle: String,
        author: String,
        lang: String,
        theme: String,
        accent: String
    ) {
        self.title = title
        self.subtitle = subtitle
        self.author = author
        self.lang = lang
        self.theme = theme
        self.accent = accent
    }
}

/// Generates per-page Open Graph PNG cards by shelling out to
/// `scripts/render-og.mjs` (satori → resvg-js). Cards are content-addressed
/// by SHA-256 of (title + subtitle + author + lang + theme + accent + tool
/// version) so re-builds with unchanged inputs are no-ops, and so any
/// theme-version-y change can invalidate every card by bumping toolVersion.
///
/// Returns nil for any failure (Node missing, font absent, satori/resvg
/// unavailable). Build keeps succeeding; pages just don't get an og:image
/// meta tag — same graceful-degradation contract as the image pipeline.
public final class OGCardGenerator {
    /// Bumped when the rendered card layout changes; invalidates every cached card.
    static let toolVersion = "og-v1"

    private let projectRoot: URL
    private let cache: BuildCache
    private let runner: NodeRunner
    private let scriptURL: URL
    private var generated: Set<String> = []

    public init(projectRoot: URL, runner: NodeRunner = NodeRunner()) {
        self.projectRoot = projectRoot
        self.cache = BuildCache(projectRoot: projectRoot)
        self.runner = runner
        self.scriptURL = projectRoot.appendingPathComponent("scripts/render-og.mjs")
    }

    public var generatedFilenames: Set<String> { generated }

    /// Returns the filename (e.g. `abc123.png`) of the generated card, or nil
    /// if generation failed. Caller is responsible for prefixing with the
    /// site's `/og/` URL.
    public func ensureCard(spec: OGCardSpec) -> String? {
        let key = computeKey(for: spec)
        let filename = "\(key).png"
        if cache.exists(for: "og", key: key, ext: "png") {
            generated.insert(filename)
            return filename
        }

        let outputPath = cache.path(for: "og", key: key, ext: "png")
        try? FileManager.default.createDirectory(
            at: outputPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let payload: [String: Any] = [
            "template": Self.builtInTemplate,
            "data": [
                "site": spec.author.isEmpty ? "" : spec.author,
                "title": spec.title,
                "subtitle": spec.subtitle,
                "accent": spec.accent
            ],
            "fontPaths": Self.candidateFontPaths(projectRoot: projectRoot, theme: spec.theme),
            "outputPath": outputPath.path,
            "width": 1200,
            "height": 630,
            "background": "#0d1117"
        ]
        guard
            let json = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
            runner.run(script: scriptURL, args: [json.base64EncodedString()]) != nil,
            cache.exists(for: "og", key: key, ext: "png")
        else {
            return nil
        }
        generated.insert(filename)
        return filename
    }

    public func cachePath(forFilename filename: String) -> URL {
        cache.root.appendingPathComponent("og", isDirectory: true).appendingPathComponent(filename)
    }

    private func computeKey(for spec: OGCardSpec) -> String {
        var hasher = SHA256()
        for value in [spec.title, spec.subtitle, spec.author, spec.lang, spec.theme, spec.accent, Self.toolVersion] {
            hasher.update(data: Data(value.utf8))
            hasher.update(data: Data([0]))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Default satori-friendly element tree. Themes can override later by
    /// shipping their own `og/template.json`; for v0.6 this single fallback
    /// is what every page uses.
    static var builtInTemplate: [String: Any] { [
        "type": "div",
        "props": [
            "style": [
                "display": "flex",
                "flexDirection": "column",
                "justifyContent": "space-between",
                "padding": 80,
                "background": "#0d1117",
                "color": "#fafaf9",
                "width": 1200,
                "height": 630
            ] as [String: Any],
            "children": [
                [
                    "type": "div",
                    "props": [
                        "style": [
                            "fontSize": 28,
                            "letterSpacing": "0.18em",
                            "textTransform": "uppercase",
                            "color": "{{accent}}"
                        ] as [String: Any],
                        "children": "{{site}}"
                    ] as [String: Any]
                ],
                [
                    "type": "div",
                    "props": [
                        "style": [
                            "fontSize": 76,
                            "fontWeight": 700,
                            "lineHeight": 1.1,
                            "marginTop": 60
                        ] as [String: Any],
                        "children": "{{title}}"
                    ] as [String: Any]
                ],
                [
                    "type": "div",
                    "props": [
                        "style": [
                            "fontSize": 30,
                            "color": "#a8a29e",
                            "marginTop": 24
                        ] as [String: Any],
                        "children": "{{subtitle}}"
                    ] as [String: Any]
                ]
            ]
        ] as [String: Any]
    ] }

    static func candidateFontPaths(projectRoot: URL, theme: String) -> [String] {
        var paths: [String] = []
        paths.append(projectRoot.appendingPathComponent("themes/\(theme)/og/font.ttf").path)
        paths.append(projectRoot.appendingPathComponent("og/font.ttf").path)
        paths.append("/System/Library/Fonts/Supplemental/Verdana.ttf")
        paths.append("/System/Library/Fonts/Supplemental/Arial.ttf")
        paths.append("/System/Library/Fonts/Supplemental/Tahoma.ttf")
        paths.append("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
        paths.append("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf")
        return paths
    }
}
