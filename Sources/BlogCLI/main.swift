import ArgumentParser

@main
struct BlogCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "blog",
        abstract: "Swift static blog generator",
        version: "0.1.0"
    )
}
