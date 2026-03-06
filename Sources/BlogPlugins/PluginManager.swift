import Foundation

public final class PluginManager {
    private let plugins: [BlogPlugin]

    public init(plugins: [BlogPlugin] = []) {
        self.plugins = plugins
    }

    public func runBeforeParse(contentPath: String) throws {
        for plugin in plugins {
            try plugin.beforeParse(contentPath: contentPath)
        }
    }

    public func runAfterParse(contentDocument: PluginDocument) throws {
        for plugin in plugins {
            try plugin.afterParse(contentDocument: contentDocument)
        }
    }

    public func runBeforeRender(routeContext: PluginRouteContext) throws {
        for plugin in plugins {
            try plugin.beforeRender(routeContext: routeContext)
        }
    }

    public func runAfterRender(outputPath: String) throws {
        for plugin in plugins {
            try plugin.afterRender(outputPath: outputPath)
        }
    }

    public func runOnBuildComplete(report: PluginBuildReport) throws {
        for plugin in plugins {
            try plugin.onBuildComplete(report: report)
        }
    }
}
