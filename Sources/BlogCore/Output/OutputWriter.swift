import Foundation

public struct OutputWriter {
    public init() {}

    public func writePages(_ pages: [BuiltPage], to outputRoot: URL) throws {
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        for page in pages {
            let relativePath: String
            if page.route == "/" {
                relativePath = "index.html"
            } else {
                let cleaned = page.route.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                relativePath = "\(cleaned)/index.html"
            }

            let fullPath = outputRoot.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(at: fullPath.deletingLastPathComponent(), withIntermediateDirectories: true)
            try page.html.write(to: fullPath, atomically: true, encoding: .utf8)
        }
    }
}
