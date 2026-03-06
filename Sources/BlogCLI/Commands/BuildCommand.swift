import ArgumentParser
import Foundation
import BlogCore

private struct BuildCommandOutput: Codable {
    let outputDirectory: String
    let routes: [String]
    let errors: [String]
}

struct BuildCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "build", abstract: "Build static output")

    @Flag(name: .long, help: "Print output as JSON")
    var json = false

    mutating func run() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let report = try BuildPipeline().run(in: root)

        if json {
            let payload = BuildCommandOutput(
                outputDirectory: report.outputDirectory.path,
                routes: report.routes,
                errors: report.errors
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            guard let output = String(data: data, encoding: .utf8) else {
                throw ValidationError("Could not encode build output as UTF-8")
            }
            print(output)
        } else {
            print("Built \(report.routes.count) route(s) -> \(report.outputDirectory.path)")
        }
    }
}
