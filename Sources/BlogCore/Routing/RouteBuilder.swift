import Foundation

public struct BuiltPage: Equatable {
    public let route: String
    public let html: String

    public init(route: String, html: String) {
        self.route = route
        self.html = html
    }
}

public struct RouteBuilder {
    public init() {}

    public func buildPages(posts: [PostDocument], renderedContent: [String: String]) -> [BuiltPage] {
        var pages: [BuiltPage] = []
        let links = posts.compactMap { post -> String? in
            guard let slug = post.frontMatter.slug, let title = post.frontMatter.title else { return nil }
            return "<li><a href=\"/posts/\(slug)/\">\(title)</a></li>"
        }

        pages.append(BuiltPage(route: "/", html: "<html><head><meta charset=\"utf-8\"><title>Home</title></head><body><main><h1>Posts</h1><ul>\(links.joined())</ul></main></body></html>"))

        for post in posts {
            guard let slug = post.frontMatter.slug, let title = post.frontMatter.title else { continue }
            let content = renderedContent[slug] ?? ""
            let html = "<html><head><meta charset=\"utf-8\"><title>\(title)</title></head><body><main><article><h1>\(title)</h1>\(content)</article></main></body></html>"
            pages.append(BuiltPage(route: "/posts/\(slug)/", html: html))
        }

        return pages
    }
}
