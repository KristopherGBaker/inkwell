import Foundation

/// Optional image source for the top-bar brand mark. When set, themes render
/// the icon in place of the auto-derived text initial; the dark-mode variant
/// (if provided) swaps in via the manual theme toggle. Values are URL paths
/// (relative or absolute) and are written verbatim into a CSS `url("...")`
/// expression — keep them free of `"` and other characters that need
/// CSS-string escaping.
public struct BrandIconConfig: Codable, Equatable {
    public var light: String
    public var dark: String?

    public init(light: String, dark: String? = nil) {
        self.light = light
        self.dark = dark
    }
}
