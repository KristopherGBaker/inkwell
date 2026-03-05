import Foundation

public enum ThemeManagerError: Error {
    case themeNotFound(String)
}

public struct ThemeManager {
    public init() {}

    public func availableThemes(in projectRoot: URL) -> [String] {
        let themesDir = projectRoot.appendingPathComponent("themes")
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: themesDir.path) else {
            return []
        }
        return items.sorted()
    }

    public func useTheme(_ name: String, in projectRoot: URL) throws {
        let selectedTheme = projectRoot.appendingPathComponent("themes/\(name)")
        guard FileManager.default.fileExists(atPath: selectedTheme.path) else {
            throw ThemeManagerError.themeNotFound(name)
        }

        let configPath = projectRoot.appendingPathComponent("blog.config.json")
        let data = try Data(contentsOf: configPath)
        var payload = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        payload["theme"] = name
        let out = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try out.write(to: configPath)
    }

    public func injectHeadAssets(into html: String) -> String {
        let tags = "<link rel=\"stylesheet\" href=\"/assets/css/prism.css\"><script defer src=\"/assets/js/prism.js\"></script>"
        if html.contains("</head>") {
            return html.replacingOccurrences(of: "</head>", with: tags + "</head>")
        }
        return tags + html
    }

    public func copyDefaultAssets(projectRoot: URL, outputRoot: URL) throws {
        let fm = FileManager.default
        let sourceRoot = projectRoot.appendingPathComponent("themes/default/assets")
        let destinationRoot = outputRoot.appendingPathComponent("assets")
        try fm.createDirectory(at: destinationRoot, withIntermediateDirectories: true)

        let cssSource = sourceRoot.appendingPathComponent("css/prism.css")
        let jsSource = sourceRoot.appendingPathComponent("js/prism.js")
        let cssDestination = destinationRoot.appendingPathComponent("css/prism.css")
        let jsDestination = destinationRoot.appendingPathComponent("js/prism.js")

        try fm.createDirectory(at: cssDestination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.createDirectory(at: jsDestination.deletingLastPathComponent(), withIntermediateDirectories: true)

        if fm.fileExists(atPath: cssSource.path) {
            if fm.fileExists(atPath: cssDestination.path) { try fm.removeItem(at: cssDestination) }
            try fm.copyItem(at: cssSource, to: cssDestination)
        }

        if fm.fileExists(atPath: jsSource.path) {
            if fm.fileExists(atPath: jsDestination.path) { try fm.removeItem(at: jsDestination) }
            try fm.copyItem(at: jsSource, to: jsDestination)
        }
    }
}
