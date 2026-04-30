import Foundation
import Stencil
import PathKit

public enum TemplateRendererError: Error, CustomStringConvertible {
    case templateBundleMissing(theme: String)
    case renderFailed(template: String, underlying: Error)

    public var description: String {
        switch self {
        case .templateBundleMissing(let theme):
            return "Template bundle for theme \"\(theme)\" not found."
        case .renderFailed(let template, let underlying):
            return "Failed to render template \"\(template)\": \(underlying)"
        }
    }
}

/// Renders Stencil templates for a given theme.
///
/// Templates are resolved from the user's project at `themes/<theme>/templates/`
/// when present; otherwise the renderer falls back to the bundled defaults
/// shipped inside the `BlogThemes` module resources.
public struct TemplateRenderer {
    private let environment: Environment
    public let theme: String

    public init(theme: String, projectRoot: URL?) throws {
        self.theme = theme
        let paths = Self.templatePaths(theme: theme, projectRoot: projectRoot)
        guard paths.isEmpty == false else {
            throw TemplateRendererError.templateBundleMissing(theme: theme)
        }

        let loader = FileSystemLoader(paths: paths.map { Path($0.path) })
        let ext = Extension()
        ext.registerFilter("escape") { (value: Any?) -> Any? in
            guard let string = value.flatMap(Self.stringify) else { return value }
            return Self.escapeHTML(string)
        }
        self.environment = Environment(loader: loader, extensions: [ext])
    }

    public func render(template: String, context: [String: Any]) throws -> String {
        let name = template.hasSuffix(".html") ? template : "\(template).html"
        do {
            return try environment.renderTemplate(name: name, context: context)
        } catch {
            throw TemplateRendererError.renderFailed(template: name, underlying: error)
        }
    }

    /// Returns the resolved theme template directories in lookup order.
    /// Project-side templates override bundled defaults; bundled defaults
    /// are always included as a fallback so users can customize individual
    /// templates without copying the entire theme.
    static func templatePaths(theme: String, projectRoot: URL?) -> [URL] {
        var paths: [URL] = []
        if let projectRoot {
            let projectThemeRoot = projectRoot
                .appendingPathComponent("themes")
                .appendingPathComponent(theme)
                .appendingPathComponent("templates")
            paths.append(projectThemeRoot)
            paths.append(projectThemeRoot.appendingPathComponent("layouts"))
            paths.append(projectThemeRoot.appendingPathComponent("partials"))
        }
        if let bundleRoot = bundledTemplatesURL(theme: theme) {
            paths.append(bundleRoot)
            paths.append(bundleRoot.appendingPathComponent("layouts"))
            paths.append(bundleRoot.appendingPathComponent("partials"))
        }
        return paths
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map { $0.resolvingSymlinksInPath() }
    }

    static func bundledTemplatesURL(theme: String) -> URL? {
        guard let resourceURL = Bundle.module.resourceURL else { return nil }
        return resourceURL
            .appendingPathComponent("themes")
            .appendingPathComponent(theme)
            .appendingPathComponent("templates")
    }

    public static func bundledThemeRoot(theme: String) -> URL? {
        guard let resourceURL = Bundle.module.resourceURL else { return nil }
        return resourceURL
            .appendingPathComponent("themes")
            .appendingPathComponent(theme)
    }

    static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func stringify(_ value: Any) -> String? {
        if let string = value as? String { return string }
        if let described = value as? CustomStringConvertible { return described.description }
        return nil
    }
}
