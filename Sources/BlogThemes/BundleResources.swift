import Foundation

/// Resolves the BlogThemes resource bundle.
///
/// Avoids `Bundle.module`, whose SwiftPM-generated accessor `fatalError`s when
/// the bundle isn't found at one of its hardcoded candidate paths. That happens
/// in two practical scenarios:
///
/// 1. Homebrew installs invoke the binary through a symlink in
///    `/opt/homebrew/bin/`, so `Bundle.main.executableURL` returns the symlink
///    path. `Bundle.module` looks for the resource bundle next to the symlink
///    (where it isn't) instead of next to the resolved binary in the Cellar.
/// 2. Custom-installed binaries (e.g. `cp .build/release/inkwell /usr/local/bin/`
///    with the bundle copied alongside) hit the same issue.
///
/// This resolver tries the executable's resolved location first, then falls
/// back to the symlink path, then the SwiftPM-baked build path. Returns nil
/// if no candidate exists; callers fall back to project-side overrides.
enum BundleResources {
    static let bundleName = "swift-blog_BlogThemes.bundle"

    static let bundleURL: URL? = findBundleURL()

    private static func findBundleURL() -> URL? {
        for candidate in candidateBundleURLs() {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return candidate
            }
        }
        return nil
    }

    private static func candidateBundleURLs() -> [URL] {
        var candidates: [URL] = []

        if let executable = Bundle.main.executableURL {
            // 1) Resolved (symlinks followed) — handles brew installs.
            let resolved = executable.resolvingSymlinksInPath().deletingLastPathComponent()
            candidates.append(resolved.appendingPathComponent(bundleName))

            // 2) Unresolved — handles direct invocation when the symlink trick isn't needed.
            let unresolved = executable.deletingLastPathComponent()
            candidates.append(unresolved.appendingPathComponent(bundleName))
        }

        // 3) Class-bundle introspection — covers framework/library hosts.
        let classBundle = Bundle(for: BundleFinder.self)
        candidates.append(classBundle.bundleURL.deletingLastPathComponent().appendingPathComponent(bundleName))
        if let resourceURL = classBundle.resourceURL {
            candidates.append(resourceURL.appendingPathComponent(bundleName))
        }

        // 4) Bundle.main fallback — last resort for app-style hosts.
        candidates.append(Bundle.main.bundleURL.appendingPathComponent(bundleName))

        return candidates
    }

    private final class BundleFinder {}
}
