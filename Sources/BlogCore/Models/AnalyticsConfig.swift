import Foundation

/// Optional analytics integration. Today only Umami is wired up; the
/// `analytics` namespace leaves room for additional providers later.
public struct AnalyticsConfig: Codable, Equatable {
    public var umami: UmamiConfig?

    public init(umami: UmamiConfig? = nil) {
        self.umami = umami
    }
}

/// Umami analytics configuration. The bundled themes inject a single
/// `<script defer>` tag with the corresponding `data-*` attributes when
/// `umami` is set.
///
/// `scriptUrl` and `websiteId` are required; everything else is optional and
/// only emitted when present. Set `domains` to your production hostname to
/// silently drop events from other origins (e.g. localhost). Set
/// `respectDoNotTrack` to honor the browser's `DNT: 1` header.
///
/// Use the `local` block to point `inkwell serve --watch` at a localhost
/// Umami instance for development. Production builds always use the top-level
/// fields; serve builds use `local` if present and inject nothing otherwise.
public struct UmamiConfig: Codable, Equatable {
    public var scriptUrl: String
    public var websiteId: String
    public var hostUrl: String?
    public var domains: String?
    public var respectDoNotTrack: Bool?
    public var tag: String?
    public var events: UmamiEventsConfig?
    public var local: UmamiLocalConfig?

    public init(
        scriptUrl: String,
        websiteId: String,
        hostUrl: String? = nil,
        domains: String? = nil,
        respectDoNotTrack: Bool? = nil,
        tag: String? = nil,
        events: UmamiEventsConfig? = nil,
        local: UmamiLocalConfig? = nil
    ) {
        self.scriptUrl = scriptUrl
        self.websiteId = websiteId
        self.hostUrl = hostUrl
        self.domains = domains
        self.respectDoNotTrack = respectDoNotTrack
        self.tag = tag
        self.events = events
        self.local = local
    }
}

/// Opt-in event tracking layered on top of the base Umami page-view script.
/// All flags default to off, so existing sites that only set the required
/// Umami fields keep recording page views and nothing else.
///
/// - `outboundLinks`: auto-track clicks on links to a different host as an
///   `outbound-link` event (covers links inside post/case-study bodies that
///   no template attribute can reach).
/// - `downloads`: auto-track clicks on file downloads (any link with a
///   `download` attribute or a path ending in one of `downloadExtensions`) as
///   a `download` event.
/// - `themeElements`: emit declarative `data-umami-event` attributes on the
///   bundled theme's known CTAs (résumé download, social links, email, hero
///   CTAs) for clean, semantic event names.
/// - `downloadExtensions`: override the built-in download extension list.
public struct UmamiEventsConfig: Codable, Equatable {
    public var outboundLinks: Bool?
    public var downloads: Bool?
    public var themeElements: Bool?
    public var downloadExtensions: [String]?

    public init(
        outboundLinks: Bool? = nil,
        downloads: Bool? = nil,
        themeElements: Bool? = nil,
        downloadExtensions: [String]? = nil
    ) {
        self.outboundLinks = outboundLinks
        self.downloads = downloads
        self.themeElements = themeElements
        self.downloadExtensions = downloadExtensions
    }
}

/// Override block applied during `inkwell serve --watch`. Fields are
/// independent of the parent `UmamiConfig` — nothing is inherited — so the
/// dev environment can point at a completely separate Umami instance.
public struct UmamiLocalConfig: Codable, Equatable {
    public var scriptUrl: String
    public var websiteId: String
    public var hostUrl: String?
    public var domains: String?
    public var respectDoNotTrack: Bool?
    public var tag: String?
    public var events: UmamiEventsConfig?

    public init(
        scriptUrl: String,
        websiteId: String,
        hostUrl: String? = nil,
        domains: String? = nil,
        respectDoNotTrack: Bool? = nil,
        tag: String? = nil,
        events: UmamiEventsConfig? = nil
    ) {
        self.scriptUrl = scriptUrl
        self.websiteId = websiteId
        self.hostUrl = hostUrl
        self.domains = domains
        self.respectDoNotTrack = respectDoNotTrack
        self.tag = tag
        self.events = events
    }
}
