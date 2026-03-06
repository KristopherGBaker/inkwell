public struct PluginDocument: Equatable {
    public let slug: String
    public let content: String

    public init(slug: String, content: String) {
        self.slug = slug
        self.content = content
    }
}

public struct PluginRouteContext: Equatable {
    public let route: String

    public init(route: String) {
        self.route = route
    }
}

public struct PluginBuildReport: Equatable {
    public let routes: [String]
    public let errors: [String]

    public init(routes: [String], errors: [String]) {
        self.routes = routes
        self.errors = errors
    }
}
