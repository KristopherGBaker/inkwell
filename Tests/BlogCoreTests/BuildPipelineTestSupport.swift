import Foundation
import XCTest
@testable import BlogCore
import BlogPlugins

func makeTempBlogProject(extraDirectories: [String] = []) throws -> URL {
    let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: temp.appendingPathComponent("content/posts"), withIntermediateDirectories: true)

    for directory in extraDirectories {
        try FileManager.default.createDirectory(at: temp.appendingPathComponent(directory), withIntermediateDirectories: true)
    }

    return temp
}

final class RecordingAfterRenderPlugin: BlogPlugin {
    var outputPaths: [String] = []

    func beforeParse(contentPath: String) throws {}
    func afterParse(contentDocument: PluginDocument) throws {}
    func beforeRender(routeContext: PluginRouteContext) throws {}
    func afterRender(outputPath: String) throws { outputPaths.append(outputPath) }
    func onBuildComplete(report: PluginBuildReport) throws {}
}
