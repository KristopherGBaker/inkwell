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

        print("Preview available at http://localhost:\(port) (serving \(root.path))")
        try app.run()
    }
}
