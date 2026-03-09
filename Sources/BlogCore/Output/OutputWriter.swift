import Foundation

public struct OutputWriter {
    public init() {}

    public func writePages(_ pages: [BuiltPage], to outputRoot: URL) throws {
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        for page in pages {
            let relativePath = outputPath(forRoute: page.route)
            let fullPath = outputRoot.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(at: fullPath.deletingLastPathComponent(), withIntermediateDirectories: true)
            try page.html.write(to: fullPath, atomically: true, encoding: .utf8)
        }
    }

    func outputPath(forRoute route: String) -> String {
        if route == "/" {
            return "index.html"
        }

        let cleaned = route.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(cleaned)/index.html"
    }

    func emittedOutputPath(forRoute route: String, outputRoot: URL, projectRoot: URL) -> String {
        let projectPath = projectRoot.standardizedFileURL.path
        let outputRootPath = outputRoot.standardizedFileURL.path
        let relativeOutputRoot: String

        if outputRootPath.hasPrefix(projectPath + "/") {
            relativeOutputRoot = String(outputRootPath.dropFirst(projectPath.count + 1))
        } else {
            relativeOutputRoot = outputRoot.lastPathComponent
        }

        return relativeOutputRoot + "/" + self.outputPath(forRoute: route)
    }

    public func writeFile(relativePath: String, content: String, to outputRoot: URL) throws {
        let fullPath = outputRoot.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: fullPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: fullPath, atomically: true, encoding: .utf8)
    }

    public func copyProjectPublicAssets(projectRoot: URL, outputRoot: URL) throws {
        let fm = FileManager.default
        let sourceRoot = projectRoot.appendingPathComponent("public")
        let standardizedSourceRootPath = sourceRoot.standardizedFileURL.path
        let standardizedOutputRootPath = outputRoot.standardizedFileURL.path
        let excludedRelativePrefix: String?

        if standardizedOutputRootPath.hasPrefix(standardizedSourceRootPath + "/") {
            excludedRelativePrefix = String(standardizedOutputRootPath.dropFirst(standardizedSourceRootPath.count + 1))
        } else {
            excludedRelativePrefix = nil
        }

        guard standardizedSourceRootPath != standardizedOutputRootPath else {
            return
        }

        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: sourceRoot.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return
        }

        for relativePath in try fm.subpathsOfDirectory(atPath: sourceRoot.path) {
            if let excludedRelativePrefix,
               relativePath == excludedRelativePrefix || relativePath.hasPrefix(excludedRelativePrefix + "/") {
                continue
            }

            let sourceURL = sourceRoot.appendingPathComponent(relativePath)
            var sourceIsDirectory: ObjCBool = false
            guard fm.fileExists(atPath: sourceURL.path, isDirectory: &sourceIsDirectory), !sourceIsDirectory.boolValue else {
                continue
            }

            let destinationURL = outputRoot.appendingPathComponent(relativePath)
            try fm.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: destinationURL.path) {
                try fm.removeItem(at: destinationURL)
            }
            try fm.copyItem(at: sourceURL, to: destinationURL)
        }
    }
}
