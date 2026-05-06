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
    public var local: UmamiLocalConfig?

    public init(
        scriptUrl: String,
        websiteId: String,
        hostUrl: String? = nil,
        domains: String? = nil,
        respectDoNotTrack: Bool? = nil,
        tag: String? = nil,
        local: UmamiLocalConfig? = nil
    ) {
        self.scriptUrl = scriptUrl
        self.websiteId = websiteId
        self.hostUrl = hostUrl
        self.domains = domains
        self.respectDoNotTrack = respectDoNotTrack
        self.tag = tag
        self.local = local
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

    public init(
        scriptUrl: String,
        websiteId: String,
        hostUrl: String? = nil,
        domains: String? = nil,
        respectDoNotTrack: Bool? = nil,
        tag: String? = nil
    ) {
        self.scriptUrl = scriptUrl
        self.websiteId = websiteId
        self.hostUrl = hostUrl
        self.domains = domains
        self.respectDoNotTrack = respectDoNotTrack
        self.tag = tag
    }
}
