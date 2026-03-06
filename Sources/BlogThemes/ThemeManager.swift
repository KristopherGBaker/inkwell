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
        let tags = """
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
        <script src="https://cdn.tailwindcss.com"></script>
        <script>
          tailwind.config = {
            darkMode: "class",
            theme: {
              extend: {
                fontFamily: {
                  display: ["Fraunces", "serif"],
                  sans: ["Manrope", "sans-serif"],
                  mono: ["JetBrains Mono", "monospace"]
                }
              }
            }
          }
        </script>
        <style>
          body { font-family: "Manrope", sans-serif; }
          .post-content p { margin-top: 1rem; font-size: 1.08rem; line-height: 1.9; }
          .post-content a { color: rgb(146 64 14); text-decoration: underline; text-decoration-color: rgb(146 64 14 / 0.4); text-underline-offset: 3px; }
          .dark .post-content a { color: rgb(251 191 36); text-decoration-color: rgb(251 191 36 / 0.45); }
          .post-content ul { margin-top: 1rem; list-style: disc; padding-left: 1.3rem; }
          .post-content li { margin-top: 0.4rem; }
          .post-content table { width: 100%; margin-top: 1.25rem; border-collapse: collapse; }
          .post-content th, .post-content td { border: 1px solid rgb(214 211 209); padding: 0.6rem 0.7rem; }
          .post-content th { background: rgb(245 245 244); text-align: left; }
          .dark .post-content th, .dark .post-content td { border-color: rgb(87 83 78); }
          .dark .post-content th { background: rgb(41 37 36); }
          .post-content code:not(pre code) { background: rgb(231 229 228); border-radius: 0.35rem; padding: 0.12rem 0.34rem; font-family: "JetBrains Mono", monospace; font-size: 0.9em; }
          .dark .post-content code:not(pre code) { background: rgb(68 64 60); }
          .post-content pre { margin-top: 1.2rem; border: 1px solid rgb(68 64 60 / 0.28); }
          .dark .post-content pre { border-color: rgb(120 113 108 / 0.45); }
          .post-content blockquote { margin-top: 1.2rem; border-left: 3px solid rgb(146 64 14 / 0.7); padding-left: 1rem; color: rgb(68 64 60); }
          .dark .post-content blockquote { border-left-color: rgb(251 191 36 / 0.6); color: rgb(214 211 209); }
        </style>
        <link rel="stylesheet" href="/assets/css/prism.css">
        <script defer src="/assets/js/prism.js"></script>
        """
        if html.contains("</head>") {
            return html.replacingOccurrences(of: "</head>", with: tags + "</head>")
        }
        return tags + html
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
