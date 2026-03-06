public protocol BlogPlugin {
    func beforeParse(contentPath: String) throws
    func afterParse(contentDocument: PluginDocument) throws
    func beforeRender(routeContext: PluginRouteContext) throws
    func afterRender(outputPath: String) throws
    func onBuildComplete(report: PluginBuildReport) throws
}

public extension BlogPlugin {
    func beforeParse(contentPath: String) throws {}
    func afterParse(contentDocument: PluginDocument) throws {}
    func beforeRender(routeContext: PluginRouteContext) throws {}
    func afterRender(outputPath: String) throws {}
    func onBuildComplete(report: PluginBuildReport) throws {}
}
