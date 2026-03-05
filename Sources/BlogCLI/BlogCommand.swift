import ArgumentParser
import Foundation
import BlogCore
import BlogThemes
import BlogPreview

@main
struct BlogCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "blog",
        abstract: "Swift static blog generator",
        version: "0.1.0",
        subcommands: [InitCommand.self, PostCommand.self, BuildCommand.self, ServeCommand.self, CheckCommand.self, ThemeCommand.self, PluginCommand.self]
    )
}
