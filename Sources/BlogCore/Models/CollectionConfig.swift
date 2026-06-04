import Foundation

public struct CollectionConfig: Codable, Equatable {
    public var id: String
    public var dir: String
    public var route: String
    public var sortBy: String?
    public var sortOrder: String?
    public var taxonomies: [String]?
    public var paginate: Int?
    public var listTemplate: String?
    public var detailTemplate: String?
    public var scaffold: String?
    /// Optional copy overrides used by list pages (e.g. work-list, post-list).
    /// `eyebrow` sets the small label above the heading; `headline` is the
    /// page H1; `lede` is the body paragraph that follows. All optional —
    /// templates fall back to defaults derived from `id`.
    public var eyebrow: String?
    public var headline: String?
    public var lede: String?
    /// When set, this collection is a *child* of the collection with this id.
    /// Child items don't get their own list/taxonomy pages; instead each item
    /// is routed under its parent item (`<parentRoute>/<parentSlug>/<slug>/`)
    /// and surfaced back on the parent as a chronological timeline.
    public var parent: String?
    /// Front-matter key on a child item naming its parent's slug. Defaults to
    /// `"parent"`. Only meaningful when `parent` is set.
    public var parentField: String?

    public init(
        id: String,
        dir: String,
        route: String,
        sortBy: String? = nil,
        sortOrder: String? = nil,
        taxonomies: [String]? = nil,
        paginate: Int? = nil,
        listTemplate: String? = nil,
        detailTemplate: String? = nil,
        scaffold: String? = nil,
        eyebrow: String? = nil,
        headline: String? = nil,
        lede: String? = nil,
        parent: String? = nil,
        parentField: String? = nil
    ) {
        self.id = id
        self.dir = dir
        self.route = route
        self.sortBy = sortBy
        self.sortOrder = sortOrder
        self.taxonomies = taxonomies
        self.paginate = paginate
        self.listTemplate = listTemplate
        self.detailTemplate = detailTemplate
        self.scaffold = scaffold
        self.eyebrow = eyebrow
        self.headline = headline
        self.lede = lede
        self.parent = parent
        self.parentField = parentField
    }

    public var resolvedSortBy: String { sortBy ?? "date" }
    public var resolvedSortOrder: String { sortOrder ?? "desc" }
    public var resolvedTaxonomies: [String] { taxonomies ?? ["tags", "categories"] }

    /// True when this collection's items hang off a parent collection.
    public var isChild: Bool { parent != nil }
    /// Front-matter key holding the parent slug for child items.
    public var resolvedParentField: String { parentField ?? "parent" }
}
