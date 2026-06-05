/// The single source of truth for the Inkwell version string.
///
/// Lives in `BlogCore` (not `BlogCLI`) so build artifacts such as feed
/// `<generator>` tags can reference it without the core depending on the CLI.
public enum InkwellVersion {
    public static let current = "0.14.0"
}
