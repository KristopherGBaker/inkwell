import ArgumentParser
import Foundation
import BlogCore

struct CheckCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "check", abstract: "Validate content and links")

    @Flag(name: .long, help: "Print output as JSON")
    var json = false

    mutating func run() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let result = LinkChecker().check(projectRoot: root)

        if json {
            let payload: [String: Any] = ["brokenLinks": result.brokenLinks, "ok": result.isValid]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            print(String(decoding: data, as: UTF8.self))
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
