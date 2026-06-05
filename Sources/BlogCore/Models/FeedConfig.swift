import Foundation

/// Optional feed configuration. When present, Inkwell emits per-collection
/// feeds for the listed collection ids and (when `combined` is true) a merged
/// "everything" feed at the site root. When absent, the legacy behavior holds:
/// a single feed at the root sourced from the primary blog collection.
public struct FeedConfig: Codable, Equatable {
    /// Emit the combined all-content feed at the site root (`/rss.xml`,
    /// `/atom.xml`, `/feed.json`, plus `/<lang>/...`). Defaults to `true` when
    /// a `feeds` block is present.
    public var combined: Bool?
    /// Collection ids that each get their own feed under that collection's
    /// route (e.g. `posts` → `/posts/rss.xml`). A child collection's items are
    /// linked under their parent (`/building/<project>/<slug>/`).
    public var collections: [String]?
    /// Maximum items per feed. Defaults to 20.
    public var limit: Int?

    public init(combined: Bool? = nil, collections: [String]? = nil, limit: Int? = nil) {
        self.combined = combined
        self.collections = collections
        self.limit = limit
    }

    /// Whether the combined root feed should be emitted (defaults to on).
    public var emitsCombined: Bool { combined ?? true }
    /// Item cap per feed, defaulting to 20.
    public var resolvedLimit: Int { limit ?? 20 }
    /// Collection ids that should get their own feed (empty when unset).
    public var resolvedCollectionIDs: [String] { collections ?? [] }
}
