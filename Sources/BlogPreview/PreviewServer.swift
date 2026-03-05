import Foundation
import Vapor

public struct PreviewServer {
    public let root: URL
    public let port: Int

    public init(root: URL = URL(fileURLWithPath: "."), port: Int = 8000) {
        self.root = root
        self.port = port
    }

    public func start() throws {
        guard FileManager.default.fileExists(atPath: root.path) else {
            throw NSError(domain: "PreviewServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Directory not found: \(root.path)"])
        }

        let app = Application(.development)
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = port
        app.middleware.use(FileMiddleware(publicDirectory: root.path))

        app.get { req async throws in
            let indexPath = root.appendingPathComponent("index.html").path
            return req.fileio.streamFile(at: indexPath)
        }

        app.get(.catchall) { req async throws in
            let path = req.parameters.getCatchall().joined(separator: "/")
            guard let filePath = resolvedFilePath(for: path) else {
                throw Abort(.notFound)
            }
            return req.fileio.streamFile(at: filePath)
        }

        print("Preview available at http://localhost:\(port) (serving \(root.path))")
        try app.run()
    }

    func resolvedFilePath(for requestPath: String) -> String? {
        let cleanedPath = requestPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if cleanedPath.isEmpty {
            let rootIndex = root.appendingPathComponent("index.html")
            return FileManager.default.fileExists(atPath: rootIndex.path) ? rootIndex.path : nil
        }

        let components = cleanedPath.split(separator: "/").map(String.init)
        if components.contains(where: { $0 == ".." }) {
            return nil
        }

        let candidate = components.reduce(root) { partial, next in
            partial.appendingPathComponent(next)
        }

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                let directoryIndex = candidate.appendingPathComponent("index.html")
                return FileManager.default.fileExists(atPath: directoryIndex.path) ? directoryIndex.path : nil
            }
            return candidate.path
        }

        if !candidate.pathExtension.isEmpty {
            return nil
        }

        let htmlCandidate = candidate.appendingPathExtension("html")
        return FileManager.default.fileExists(atPath: htmlCandidate.path) ? htmlCandidate.path : nil
    }
}
