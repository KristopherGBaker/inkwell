import ArgumentParser

struct PluginCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "plugin",
        abstract: "Manage plugins",
        subcommands: [PluginListCommand.self, PluginEnableCommand.self, PluginDisableCommand.self]
    )
}

struct PluginListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List plugin state")

    mutating func run() throws {
        print("Plugins are local-only in v1")
    }
}

struct PluginEnableCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "enable", abstract: "Enable plugin")

    @Argument var name: String

    mutating func run() throws {
        print("Enabled plugin: \(name)")
    }
}

struct PluginDisableCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "disable", abstract: "Disable plugin")

    @Argument var name: String

    mutating func run() throws {
        print("Disabled plugin: \(name)")
    }
}
