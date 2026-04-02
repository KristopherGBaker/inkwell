import Foundation

public enum ThemeManagerError: Error {
    case themeNotFound(String)
}

private struct BlogConfigPayload: Codable {
    var title: String
    var baseURL: String
    var theme: String
    var outputDir: String

    init(title: String = "My Blog", baseURL: String = "/", theme: String = "default", outputDir: String = "docs") {
        self.title = title
        self.baseURL = baseURL
        self.theme = theme
        self.outputDir = outputDir
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "My Blog"
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? "/"
        theme = try container.decodeIfPresent(String.self, forKey: .theme) ?? "default"
        outputDir = try container.decodeIfPresent(String.self, forKey: .outputDir) ?? "docs"
    }
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
        var payload = try JSONDecoder().decode(BlogConfigPayload.self, from: data)
        payload.theme = name
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let out = try encoder.encode(payload)
        try out.write(to: configPath)
    }

    public func injectHeadAssets(into html: String, baseURL: String = "/") -> String {
        let assetPrefix = normalizedAssetPrefix(from: baseURL)
        let tags = """
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <script>
          (function() {
            var saved = localStorage.getItem("theme");
            var dark = saved ? saved === "dark" : window.matchMedia("(prefers-color-scheme: dark)").matches;
            document.documentElement.classList.toggle("dark", dark);
          })();

          function toggleTheme() {
            var isDark = document.documentElement.classList.toggle("dark");
            localStorage.setItem("theme", isDark ? "dark" : "light");
          }
        </script>
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,500;9..144,700&family=Manrope:wght@400;500;700&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
        <link rel="stylesheet" href="\(assetPrefix)/assets/css/tailwind.css">
        <link rel="stylesheet" href="\(assetPrefix)/assets/css/prism.css">
        <script type="module">
          import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
          mermaid.initialize({ startOnLoad: false, securityLevel: "loose" });
          window.addEventListener("DOMContentLoaded", function() {
            mermaid.run({ querySelector: ".mermaid" }).catch(function() {});
          });
        </script>
        <script defer src="\(assetPrefix)/assets/js/search.js"></script>
        <script defer src="\(assetPrefix)/assets/js/prism.js"></script>
        """
        if html.contains("</head>") {
            return html.replacingOccurrences(of: "</head>", with: tags + "</head>")
        }
        return tags + html
    }

    private func normalizedAssetPrefix(from baseURL: String) -> String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, trimmed != "/" else {
            return ""
        }

        if let components = URLComponents(string: trimmed) {
            // Full URL (has a scheme) — use only the path component
            if components.scheme != nil {
                let path = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
                return (path.isEmpty || path == "/") ? "" : path
            }
            // Path-only URL
            if components.path.isEmpty == false, components.path != "/" {
                return components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
            }
        }

        let normalized = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        guard normalized.isEmpty == false, normalized != "/" else {
            return ""
        }
        return normalized.hasPrefix("/") ? normalized : "/\(normalized)"
    }

    public func copyDefaultAssets(projectRoot: URL, outputRoot: URL) throws {
        let fm = FileManager.default
        let sourceRoot = projectRoot.appendingPathComponent("themes/default/assets")
        let destinationRoot = outputRoot.appendingPathComponent("assets")
        if fm.fileExists(atPath: destinationRoot.path) {
            try fm.removeItem(at: destinationRoot)
        }
        try fm.createDirectory(at: destinationRoot, withIntermediateDirectories: true)

        guard fm.fileExists(atPath: sourceRoot.path) else { return }
        let files = try fm.subpathsOfDirectory(atPath: sourceRoot.path)
        for relative in files {
            let source = sourceRoot.appendingPathComponent(relative)
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: source.path, isDirectory: &isDirectory), !isDirectory.boolValue else { continue }
            let destination = destinationRoot.appendingPathComponent(relative)
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: source, to: destination)
        }
    }
}
