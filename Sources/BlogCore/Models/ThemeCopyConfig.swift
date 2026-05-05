import Foundation

/// Site-wide theme strings not tied to a specific page identity. Themes pick
/// up these strings to render their non-content chrome (back-links, "next"
/// labels, 404 copy, etc.). Each field is optional and falls back to the
/// theme's default English string when unset.
public struct ThemeCopyConfig: Codable, Equatable {
    public var workCardCta: String?
    public var caseStudyBack: String?
    public var caseStudyNextLabel: String?
    public var caseStudyNextFallbackCta: String?
    public var aboutEyebrow: String?
    public var aboutResumeCta: String?
    public var aboutEmailCta: String?
    public var postBack: String?
    public var postMoreCta: String?
    public var postReplyEmailCta: String?
    public var postMinRead: String?
    /// printf-style format string for reading time. Default `"%d min read"`.
    /// Translatable per language via the `translations.<lang>.themeCopy`
    /// overlay.
    public var readingTimeLabel: String?
    public var notFoundEyebrow: String?
    public var notFoundHeadline: String?
    public var notFoundBody: String?
    public var notFoundCta: String?
    public var themeToggleLabel: String?

    public init(
        workCardCta: String? = nil,
        caseStudyBack: String? = nil,
        caseStudyNextLabel: String? = nil,
        caseStudyNextFallbackCta: String? = nil,
        aboutEyebrow: String? = nil,
        aboutResumeCta: String? = nil,
        aboutEmailCta: String? = nil,
        postBack: String? = nil,
        postMoreCta: String? = nil,
        postReplyEmailCta: String? = nil,
        postMinRead: String? = nil,
        readingTimeLabel: String? = nil,
        notFoundEyebrow: String? = nil,
        notFoundHeadline: String? = nil,
        notFoundBody: String? = nil,
        notFoundCta: String? = nil,
        themeToggleLabel: String? = nil
    ) {
        self.workCardCta = workCardCta
        self.caseStudyBack = caseStudyBack
        self.caseStudyNextLabel = caseStudyNextLabel
        self.caseStudyNextFallbackCta = caseStudyNextFallbackCta
        self.aboutEyebrow = aboutEyebrow
        self.aboutResumeCta = aboutResumeCta
        self.aboutEmailCta = aboutEmailCta
        self.postBack = postBack
        self.postMoreCta = postMoreCta
        self.postReplyEmailCta = postReplyEmailCta
        self.postMinRead = postMinRead
        self.readingTimeLabel = readingTimeLabel
        self.notFoundEyebrow = notFoundEyebrow
        self.notFoundHeadline = notFoundHeadline
        self.notFoundBody = notFoundBody
        self.notFoundCta = notFoundCta
        self.themeToggleLabel = themeToggleLabel
    }
}
