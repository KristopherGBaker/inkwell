import BlogRenderer
import CryptoKit
import Foundation

/// Variant generation request: which widths and formats the renderer wants.
public struct ImageVariantSpec: Codable, Equatable, Sendable {
    public let widths: [Int]
    public let formats: [String]
    public let minBytes: Int

    public init(widths: [Int], formats: [String], minBytes: Int = 32_768) {
        self.widths = widths
        self.formats = formats
        self.minBytes = minBytes
    }

    public static let defaults = ImageVariantSpec(
        widths: [480, 800, 1200, 1600],
        formats: ["avif", "webp"]
    )
}

/// One generated cached output: width, format, and the on-disk filename inside
/// the cache bucket. Resolve to a full path via `ImageVariantGenerator.cachePath(for:)`.
public struct ImageVariant: Codable, Equatable, Sendable {
    public let width: Int
    public let format: String
    public let filename: String
}

public struct ImageMetadata: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let format: String
    public let bypassed: Bool
    public let reason: String?
}

public struct ImageVariantResult: Codable, Equatable, Sendable {
    public let metadata: ImageMetadata
    public let variants: [ImageVariant]
}

/// Coordinates resize/format-conversion of a source image into cached variants
/// by shelling out to `scripts/process-image.mjs` (sharp). Returns nil for any
/// failure mode — Phase 3 picture rewriting falls back to a plain `<img>`
/// when this returns nil, mirroring how shiki degrades when Node is missing.
public struct ImageVariantGenerator {
    /// Bumped when the script's output contract changes; invalidates caches.
    static let toolVersion = "image-pipeline-v1"

    private let projectRoot: URL
    private let cache: BuildCache
    private let runner: NodeRunner
    private let scriptURL: URL

    public init(projectRoot: URL, runner: NodeRunner = NodeRunner()) {
        self.projectRoot = projectRoot
        self.cache = BuildCache(projectRoot: projectRoot)
        self.runner = runner
        self.scriptURL = projectRoot.appendingPathComponent("scripts/process-image.mjs")
    }

    public func cachePath(for variant: ImageVariant) -> URL {
        cache.root.appendingPathComponent("images", isDirectory: true)
            .appendingPathComponent(variant.filename)
    }

    public func ensureVariants(source: URL, spec: ImageVariantSpec = .defaults) -> ImageVariantResult? {
        guard let sourceBytes = try? Data(contentsOf: source) else { return nil }
        let key = Self.computeKey(sourceBytes: sourceBytes, spec: spec)

        if let cached = readManifest(key: key) {
            return cached
        }

        guard let specJSON = try? String(data: JSONEncoder().encode(spec), encoding: .utf8) else {
            return nil
        }

        let outDir = cache.root.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        guard let stdout = runner.run(
            script: scriptURL,
            args: [source.path, outDir.path, key, specJSON]
        ) else {
            return nil
        }

        guard let result = try? JSONDecoder().decode(ImageVariantResult.self, from: stdout) else {
            return nil
        }

        if let manifestData = try? JSONEncoder().encode(result) {
            try? cache.write(manifestData, for: "images", key: key, ext: "json")
        }

        return result
    }

    private func readManifest(key: String) -> ImageVariantResult? {
        let url = cache.path(for: "images", key: key, ext: "json")
        guard let data = try? Data(contentsOf: url), data.isEmpty == false else { return nil }
        return try? JSONDecoder().decode(ImageVariantResult.self, from: data)
    }

    static func computeKey(sourceBytes: Data, spec: ImageVariantSpec) -> String {
        var hasher = SHA256()
        hasher.update(data: sourceBytes)
        let encoder = JSONEncoder()
        // Sorted keys give a stable encoding; without it Foundation's
        // JSONEncoder may emit struct properties in different orders on
        // different calls in Swift 6, which would produce a different
        // hash for identical inputs and break the cache short-circuit.
        encoder.outputFormatting = [.sortedKeys]
        if let specData = try? encoder.encode(spec) {
            hasher.update(data: specData)
        }
        hasher.update(data: Data(toolVersion.utf8))
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
