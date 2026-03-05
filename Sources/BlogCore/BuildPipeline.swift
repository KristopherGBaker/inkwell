import Foundation
import BlogPlugins
import BlogRenderer
import BlogThemes

public struct BuildReport {
    public let outputDirectory: URL
    public let routes: [String]
    public let errors: [String]

    public init(outputDirectory: URL, routes: [String], errors: [String]) {
        self.outputDirectory = outputDirectory
        self.routes = routes
        self.errors = errors
    }
}

public struct BuildPipeline {
    public init() {}
}
