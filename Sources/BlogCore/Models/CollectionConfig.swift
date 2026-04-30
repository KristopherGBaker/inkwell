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
        scaffold: String? = nil
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
    }

    public var resolvedSortBy: String { sortBy ?? "date" }
    public var resolvedSortOrder: String { sortOrder ?? "desc" }
    public var resolvedTaxonomies: [String] { taxonomies ?? ["tags", "categories"] }
}
