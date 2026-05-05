import Foundation

/// Runs a Node.js script and returns its stdout, or nil for any failure mode
/// (missing script, non-zero exit, empty output, spawn error).
///
/// The "nil on failure" contract lets callers fall back to a simpler render
/// path without having to distinguish causes — matches the way the existing
/// shiki integration degrades when Node or `node_modules/` is unavailable.
public struct NodeRunner {
    public init() {}

    public func run(script: URL, args: [String]) -> Data? {
        guard FileManager.default.fileExists(atPath: script.path) else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["node", script.path] + args

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            return data.isEmpty ? nil : data
        } catch {
            return nil
        }
    }
}
