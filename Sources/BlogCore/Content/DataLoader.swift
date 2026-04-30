import Foundation
import Yams

public enum DataLoaderError: Error, CustomStringConvertible {
    case decodeFailed(URL, underlying: Error)

    public var description: String {
        switch self {
        case .decodeFailed(let url, let underlying):
            return "Failed to load data file \(url.lastPathComponent): \(underlying)"
        }
    }
}

/// Loads `data/*.yml`, `data/*.yaml`, and `data/*.json` files into a
/// dictionary keyed by file basename. Each file's contents are decoded
/// to plain Swift values (`String`, `Int`, `Double`, `Bool`, `[Any]`,
/// `[String: Any]`) so they can be passed straight into a Stencil
/// template context.
public struct DataLoader {
    public init() {}

    public func load(in projectRoot: URL) throws -> [String: Any] {
        let dataDir = projectRoot.appendingPathComponent("data")
        var isDirectory: ObjCBool = false
        guard
            FileManager.default.fileExists(atPath: dataDir.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            return [:]
        }

        let files = try FileManager.default.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: nil)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var result: [String: Any] = [:]
        for url in files {
            let name = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension.lowercased()
            do {
                switch ext {
                case "yml", "yaml":
                    let text = try String(contentsOf: url, encoding: .utf8)
                    if let decoded = try Yams.load(yaml: text) {
                        result[name] = decoded
                    }
                case "json":
                    let bytes = try Data(contentsOf: url)
                    result[name] = try JSONSerialization.jsonObject(with: bytes, options: [])
                default:
                    continue
                }
            } catch {
                throw DataLoaderError.decodeFailed(url, underlying: error)
            }
        }
        return result
    }
}
