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
///
/// Files with a `<basename>.<lang>.<ext>` suffix are treated as
/// translations of `<basename>.<ext>`. Calling `load(in:, lang:)` with a
/// non-default language prefers the suffixed file when present and falls
/// back to the unsuffixed file otherwise.
public struct DataLoader {
    public init() {}

    public func load(in projectRoot: URL, lang: String = "en") throws -> [String: Any] {
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

        // Group by basename so we can pick the right variant per language.
        var byBase: [String: [String: URL]] = [:]
        for url in files {
            let ext = url.pathExtension.lowercased()
            guard ["yml", "yaml", "json"].contains(ext) else { continue }
            let filename = url.lastPathComponent
            let (base, fileLang) = Self.splitDataFilename(filename)
            byBase[base, default: [:]][fileLang ?? ""] = url
        }

        var result: [String: Any] = [:]
        for (base, variants) in byBase {
            // Prefer the requested language; fall back to the unsuffixed file.
            guard let url = variants[lang] ?? variants[""] else { continue }
            do {
                switch url.pathExtension.lowercased() {
                case "yml", "yaml":
                    let text = try String(contentsOf: url, encoding: .utf8)
                    if let decoded = try Yams.load(yaml: text) {
                        result[base] = decoded
                    }
                case "json":
                    let bytes = try Data(contentsOf: url)
                    result[base] = try JSONSerialization.jsonObject(with: bytes, options: [])
                default:
                    continue
                }
            } catch {
                throw DataLoaderError.decodeFailed(url, underlying: error)
            }
        }
        return result
    }

    /// Splits `resume.ja.yml` into (`"resume"`, `"ja"`) and `resume.yml`
    /// into (`"resume"`, nil). Recognizes BCP-47 lang tags (lowercase 2–3
    /// letters with optional `-XX` region).
    static func splitDataFilename(_ filename: String) -> (base: String, lang: String?) {
        let nsName = filename as NSString
        let ext = nsName.pathExtension
        guard ext.isEmpty == false else { return (filename, nil) }
        let withoutExt = nsName.deletingPathExtension
        if let dot = withoutExt.lastIndex(of: ".") {
            let candidate = String(withoutExt[withoutExt.index(after: dot)...])
            if isLanguageTag(candidate) {
                return (String(withoutExt[..<dot]), candidate)
            }
        }
        return (withoutExt, nil)
    }

    private static func isLanguageTag(_ value: String) -> Bool {
        let parts = value.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let primary = parts[0]
        guard (2...3).contains(primary.count), primary.allSatisfy({ $0.isLetter && $0.isLowercase }) else {
            return false
        }
        if parts.count == 2 {
            let region = parts[1]
            guard region.count == 2, region.allSatisfy({ $0.isLetter && $0.isUppercase }) else {
                return false
            }
        }
        return true
    }
}
