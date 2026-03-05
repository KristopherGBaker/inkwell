import Foundation

public enum SchemaValidatorError: Error, Equatable, LocalizedError {
    case missingField(String)
    case invalidDate(String)

    public var errorDescription: String? {
        switch self {
        case let .missingField(field):
            return "Missing required field: \(field)"
        case let .invalidDate(value):
            return "Invalid ISO date: \(value)"
        }
    }
}

public enum SchemaValidator {
    public static func validate(frontMatter: PostFrontMatter) throws {
        guard let title = frontMatter.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SchemaValidatorError.missingField("title")
        }

        guard let slug = frontMatter.slug, !slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SchemaValidatorError.missingField("slug")
        }

        guard let date = frontMatter.date, !date.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SchemaValidatorError.missingField("date")
        }

        let formatter = ISO8601DateFormatter()
        if formatter.date(from: date) == nil {
            throw SchemaValidatorError.invalidDate(date)
        }
    }
}
