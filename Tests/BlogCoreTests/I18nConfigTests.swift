import Foundation
import XCTest
@testable import BlogCore

final class I18nConfigTests: XCTestCase {
    func testDecodesI18nBlock() throws {
        let json = #"""
        {
          "title": "Kris",
          "i18n": { "defaultLanguage": "en", "languages": ["en", "ja"] }
        }
        """#
        let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.i18n?.defaultLanguage, "en")
        XCTAssertEqual(config.i18n?.languages, ["en", "ja"])
    }

    func testI18nDefaultsWhenLanguagesOmitted() throws {
        let json = #"""
        {
          "title": "Kris",
          "i18n": { "defaultLanguage": "ja" }
        }
        """#
        let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.i18n?.defaultLanguage, "ja")
        XCTAssertEqual(config.i18n?.resolvedLanguages, ["ja"])
    }

    func testI18nDefaultsWhenDefaultLanguageOmitted() throws {
        let json = #"""
        {
          "title": "Kris",
          "i18n": { "languages": ["en", "ja"] }
        }
        """#
        let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.i18n?.resolvedDefaultLanguage, "en")
        XCTAssertEqual(config.i18n?.languages, ["en", "ja"])
    }

    func testLegacyConfigHasNoI18n() throws {
        let json = #"{"title":"Field Notes","baseURL":"/"}"#
        let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
        XCTAssertNil(config.i18n)
        XCTAssertNil(config.translations)
    }

    func testDecodesTranslationsOverlay() throws {
        let json = #"""
        {
          "title": "Kris",
          "i18n": { "defaultLanguage": "en", "languages": ["en", "ja"] },
          "heroHeadline": "I build *millions* of...",
          "translations": {
            "ja": {
              "heroHeadline": "数百万人のための...",
              "tagline": "東京 · お話しましょう",
              "footerCta": { "headline": "良い仕事に静かに開いています。" },
              "themeCopy": { "workCardCta": "ケーススタディを読む" },
              "home": { "featuredLabel": "選ばれた仕事" },
              "author": { "tagline": "iOS · 成長 · 東京" },
              "collections": [{ "id": "posts", "headline": "ある現場のメモ。" }]
            }
          }
        }
        """#
        let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
        let ja = config.translations?["ja"]
        XCTAssertEqual(ja?.heroHeadline, "数百万人のための...")
        XCTAssertEqual(ja?.tagline, "東京 · お話しましょう")
        XCTAssertEqual(ja?.footerCta?.headline, "良い仕事に静かに開いています。")
        XCTAssertEqual(ja?.themeCopy?.workCardCta, "ケーススタディを読む")
        XCTAssertEqual(ja?.home?.featuredLabel, "選ばれた仕事")
        XCTAssertEqual(ja?.author?.tagline, "iOS · 成長 · 東京")
        XCTAssertEqual(ja?.collections?.first?.id, "posts")
        XCTAssertEqual(ja?.collections?.first?.headline, "ある現場のメモ。")
    }
}
