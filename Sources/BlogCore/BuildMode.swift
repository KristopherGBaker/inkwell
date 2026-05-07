import Foundation

/// Distinguishes a one-shot CLI build from a `serve --watch` rebuild. Used by
/// the build pipeline and template context to switch between production
/// integrations and their local-development overrides (e.g. Umami's
/// `analytics.umami` vs `analytics.umami.local`).
public enum BuildMode: Sendable, Equatable {
    case build
    case serve
}
