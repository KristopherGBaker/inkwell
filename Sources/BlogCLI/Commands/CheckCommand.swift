import ArgumentParser
import Foundation
import BlogCore

private struct CheckCommandOutput: Codable {
    let brokenLinks: [String]
    let errors: [String]
    let ok: Bool
}

struct CheckCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "check", abstract: "Validate content and links")

    @Flag(name: .long, help: "Print output as JSON")
    var json = false

    mutating func run() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let result = ProjectChecker().check(projectRoot: root)

        if json {
            let payload = CheckCommandOutput(brokenLinks: result.brokenLinks, errors: result.errors, ok: result.isValid)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            guard let output = String(data: data, encoding: .utf8) else {
                throw ValidationError("Could not encode check output as UTF-8")
            }
            print(output)
            if !result.isValid {
                throw ExitCode.failure
            }
        } else if result.isValid {
            print("Check passed")
        } else {
            for link in result.brokenLinks {
                fputs("broken link: \(link)\n", stderr)
            }
            for error in result.errors {
                fputs("error: \(error)\n", stderr)
            }
            throw ExitCode.failure
        }
    }
}
