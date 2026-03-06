import ArgumentParser
import Foundation
import BlogThemes

struct ThemeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "theme",
        abstract: "Manage themes",
        subcommands: [ThemeListCommand.self, ThemeUseCommand.self]
    )
}

struct ThemeListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List available themes")

    mutating func run() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for theme in ThemeManager().availableThemes(in: root) {
            print(theme)
        }
    }
}

struct ThemeUseCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "use", abstract: "Select active theme")

    @Argument
    var name: String

    mutating func run() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        try ThemeManager().useTheme(name, in: root)
        print("Using theme: \(name)")
    }
}
