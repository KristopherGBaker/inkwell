import ArgumentParser
import Foundation
import BlogCore

private struct CheckCommandOutput: Codable {
    let brokenLinks: [String]
    let ok: Bool
}

struct CheckCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "check", abstract: "Validate content and links")

    @Flag(name: .long, help: "Print output as JSON")
    var json = false

    mutating func run() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let result = LinkChecker().check(projectRoot: root)

        if json {
            let payload = CheckCommandOutput(brokenLinks: result.brokenLinks, ok: result.isValid)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            guard let output = String(data: data, encoding: .utf8) else {
                throw ValidationError("Could not encode check output as UTF-8")
            }
            print(output)
        } else if result.isValid {
            print("Check passed")
        } else {
            for link in result.brokenLinks {
                fputs("broken link: \(link)\n", stderr)
            }
            throw ExitCode.failure
        }
    }
}
