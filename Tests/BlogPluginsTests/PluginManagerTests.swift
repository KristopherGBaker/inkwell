import XCTest
@testable import BlogPlugins

final class PluginManagerTests: XCTestCase {
    func testHooksRunInExpectedOrder() throws {
        let recorder = RecordingPlugin()
        let manager = PluginManager(plugins: [recorder])

        try manager.runBeforeParse(contentPath: "content/posts/x.md")
        try manager.runAfterParse(contentDocument: PluginDocument(slug: "x", content: "body"))
        try manager.runBeforeRender(routeContext: PluginRouteContext(route: "/posts/x/"))
        try manager.runAfterRender(outputPath: "docs/posts/x/index.html")
        try manager.runOnBuildComplete(report: PluginBuildReport(routes: ["/posts/x/"], errors: []))

        XCTAssertEqual(recorder.calls, ["beforeParse", "afterParse", "beforeRender", "afterRender", "onBuildComplete"])
    }
}

private final class RecordingPlugin: BlogPlugin {
    var calls: [String] = []

    func beforeParse(contentPath: String) throws { calls.append("beforeParse") }
    func afterParse(contentDocument: PluginDocument) throws { calls.append("afterParse") }
    func beforeRender(routeContext: PluginRouteContext) throws { calls.append("beforeRender") }
    func afterRender(outputPath: String) throws { calls.append("afterRender") }
    func onBuildComplete(report: PluginBuildReport) throws { calls.append("onBuildComplete") }
}
