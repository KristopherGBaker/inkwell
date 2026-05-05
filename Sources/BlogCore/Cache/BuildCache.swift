import Foundation

/// Content-addressable scratch space rooted at `<projectRoot>/.inkwell-cache/`.
///
/// Cache consumers compute a stable key (typically a hash of inputs + tool
/// version) and ask the cache for an artifact path under a category bucket.
/// `exists` short-circuits work when the keyed file is present and non-empty;
/// `write` lays the bytes down atomically so partial files never look valid.
public struct BuildCache {
    public let root: URL

    public init(projectRoot: URL) {
        self.root = projectRoot.appendingPathComponent(".inkwell-cache", isDirectory: true)
    }

    public func path(for category: String, key: String, ext: String) -> URL {
        let normalizedExt = ext.hasPrefix(".") ? String(ext.dropFirst()) : ext
        return root
            .appendingPathComponent(category, isDirectory: true)
            .appendingPathComponent("\(key).\(normalizedExt)")
    }

    /// True only when the artifact exists *and* has non-zero size — a partial
    /// or interrupted write leaves a zero-byte file, and we want the next
    /// build to redo the work rather than serve a corrupt artifact.
    public func exists(for category: String, key: String, ext: String) -> Bool {
        let url = path(for: category, key: key, ext: ext)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber else {
            return false
        }
        return size.intValue > 0
    }

    public func write(_ data: Data, for category: String, key: String, ext: String) throws {
        let dest = path(for: category, key: key, ext: ext)
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: dest, options: .atomic)
    }
}
