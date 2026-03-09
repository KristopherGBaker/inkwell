import Foundation

enum TaxonomySlugCollisionValidator {
    struct Collision {
        let kind: String
        let slug: String
        let labels: [String]
    }

    static func firstCollision(in posts: [PostDocument]) -> Collision? {
        firstCollision(kind: "tags", posts: posts) { $0.frontMatter.tags ?? [] }
            ?? firstCollision(kind: "categories", posts: posts) { $0.frontMatter.categories ?? [] }
    }

    private static func firstCollision(
        kind: String,
        posts: [PostDocument],
        extractor: (PostDocument) -> [String]
    ) -> Collision? {
        var labelsBySlug: [String: Set<String>] = [:]

        for post in posts where post.frontMatter.draft != true {
            for label in extractor(post) {
                let slug = taxonomySlug(label)
                labelsBySlug[slug, default: []].insert(label)
            }
        }

        guard let collision = labelsBySlug.first(where: { $0.value.count > 1 }) else {
            return nil
        }

        return Collision(kind: kind, slug: collision.key, labels: collision.value.sorted())
    }

    private static func taxonomySlug(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
