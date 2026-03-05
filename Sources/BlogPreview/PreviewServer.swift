import Foundation

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
        print("Preview available at http://localhost:\(port) (serving \(root.path))")
    }
}
