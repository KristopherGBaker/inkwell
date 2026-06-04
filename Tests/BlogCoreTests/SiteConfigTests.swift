import Foundation
import XCTest
@testable import BlogCore

final class SiteConfigTests: XCTestCase {
    func testDecodesAuthorAndNavAndCollectionsAndHome() throws {
        let json = """
        {
          "title": "Kris",
          "baseURL": "https://krisbaker.com/",
          "author": {
            "name": "Kristopher Baker",
            "role": "Senior Software Engineer",
            "social": [{ "label": "GitHub", "url": "https://github.com/x" }]
          },
          "nav": [{ "label": "Work", "route": "/work/" }],
          "collections": [
            {
              "id": "projects",
              "dir": "content/projects",
              "route": "/work",
              "sortBy": "year",
              "sortOrder": "desc",
              "taxonomies": ["tags"]
            }
          ],
          "home": {
            "template": "landing",
            "featuredCollection": "projects",
            "featuredCount": 4
          }
        }
        """
        let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.author?.name, "Kristopher Baker")
        XCTAssertEqual(config.author?.role, "Senior Software Engineer")
        XCTAssertEqual(config.author?.social?.first?.label, "GitHub")
        XCTAssertEqual(config.nav?.first?.route, "/work/")
        XCTAssertEqual(config.collections?.first?.id, "projects")
        XCTAssertEqual(config.collections?.first?.resolvedSortBy, "year")
        XCTAssertEqual(config.home?.featuredCollection, "projects")
        XCTAssertEqual(config.home?.featuredCount, 4)
    }

    func testDecodesLegacyConfigWithoutNewFields() throws {
        let json = #"{"title":"Field Notes","baseURL":"/"}"#
        let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.title, "Field Notes")
        XCTAssertNil(config.author)
        XCTAssertNil(config.nav)
        XCTAssertNil(config.collections)
        XCTAssertNil(config.home)
    }

    func testCollectionDefaultsApplyWhenSortAndTaxonomiesOmitted() throws {
        let json = #"{"id":"posts","dir":"content/posts","route":"/posts"}"#
        let collection = try JSONDecoder().decode(CollectionConfig.self, from: Data(json.utf8))
        XCTAssertEqual(collection.resolvedSortBy, "date")
        XCTAssertEqual(collection.resolvedSortOrder, "desc")
        XCTAssertEqual(collection.resolvedTaxonomies, ["tags", "categories"])
    }

    func testDecodesBrandIconWithLightAndDark() throws {
        let json = """
        {
          "title": "Kris",
          "baseURL": "/",
          "brandIcon": {
            "light": "/assets/icons/kb.png",
            "dark": "/assets/icons/kb-dark.png"
          }
        }
        """
        let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.brandIcon?.light, "/assets/icons/kb.png")
        XCTAssertEqual(config.brandIcon?.dark, "/assets/icons/kb-dark.png")
    }

    func testDecodesBrandIconWithLightOnly() throws {
        let json = #"{"title":"Kris","baseURL":"/","brandIcon":{"light":"/icon.png"}}"#
        let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.brandIcon?.light, "/icon.png")
        XCTAssertNil(config.brandIcon?.dark)
    }

    func testDecodesAnalyticsUmamiProdBlockOnly() throws {
        let json = """
        {
          "title": "Kris",
          "baseURL": "/",
          "analytics": {
            "umami": {
              "scriptUrl": "https://analytics.krisbaker.com/script.js",
              "websiteId": "abc-123",
              "hostUrl": "https://analytics.krisbaker.com",
              "domains": "krisbaker.com",
              "respectDoNotTrack": true,
              "tag": "site"
            }
          }
        }
        """
        let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
        let umami = try XCTUnwrap(config.analytics?.umami)
        XCTAssertEqual(umami.scriptUrl, "https://analytics.krisbaker.com/script.js")
        XCTAssertEqual(umami.websiteId, "abc-123")
        XCTAssertEqual(umami.hostUrl, "https://analytics.krisbaker.com")
        XCTAssertEqual(umami.domains, "krisbaker.com")
        XCTAssertEqual(umami.respectDoNotTrack, true)
        XCTAssertEqual(umami.tag, "site")
        XCTAssertNil(umami.local)
    }

    func testDecodesAnalyticsUmamiWithLocalOverride() throws {
        let json = """
        {
          "title": "Kris",
          "baseURL": "/",
          "analytics": {
            "umami": {
              "scriptUrl": "https://analytics.krisbaker.com/script.js",
              "websiteId": "abc-123",
              "domains": "krisbaker.com",
              "local": {
                "scriptUrl": "http://localhost:3000/script.js",
                "websiteId": "local-456",
                "hostUrl": "http://localhost:3000",
                "domains": "localhost"
              }
            }
          }
        }
        """
        let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
        let umami = try XCTUnwrap(config.analytics?.umami)
        XCTAssertEqual(umami.scriptUrl, "https://analytics.krisbaker.com/script.js")
        XCTAssertEqual(umami.websiteId, "abc-123")
        XCTAssertEqual(umami.domains, "krisbaker.com")
        let local = try XCTUnwrap(umami.local)
        XCTAssertEqual(local.scriptUrl, "http://localhost:3000/script.js")
        XCTAssertEqual(local.websiteId, "local-456")
        XCTAssertEqual(local.hostUrl, "http://localhost:3000")
        XCTAssertEqual(local.domains, "localhost")
        XCTAssertNil(local.respectDoNotTrack)
        XCTAssertNil(local.tag)
    }

    func testDecodesAnalyticsUmamiMinimalRequiredFields() throws {
        // swiftlint:disable:next line_length
        let json = #"{"title":"Kris","baseURL":"/","analytics":{"umami":{"scriptUrl":"https://x/s.js","websiteId":"id"}}}"#
        let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
        let umami = try XCTUnwrap(config.analytics?.umami)
        XCTAssertEqual(umami.scriptUrl, "https://x/s.js")
        XCTAssertEqual(umami.websiteId, "id")
        XCTAssertNil(umami.hostUrl)
        XCTAssertNil(umami.domains)
        XCTAssertNil(umami.respectDoNotTrack)
        XCTAssertNil(umami.tag)
        XCTAssertNil(umami.events)
        XCTAssertNil(umami.local)
    }

    func testDecodesAnalyticsUmamiEventsBlock() throws {
        let json = """
        {
          "title": "Kris",
          "baseURL": "/",
          "analytics": {
            "umami": {
              "scriptUrl": "https://x/s.js",
              "websiteId": "id",
              "events": {
                "outboundLinks": true,
                "downloads": true,
                "themeElements": true,
                "downloadExtensions": ["pdf", "zip"]
              }
            }
          }
        }
        """
        let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
        let events = try XCTUnwrap(config.analytics?.umami?.events)
        XCTAssertEqual(events.outboundLinks, true)
        XCTAssertEqual(events.downloads, true)
        XCTAssertEqual(events.themeElements, true)
        XCTAssertEqual(events.downloadExtensions, ["pdf", "zip"])
    }

    func testDecodesAnalyticsUmamiEventsPartialBlock() throws {
        // Only one flag set; the rest stay nil and downloadExtensions is omitted.
        // swiftlint:disable:next line_length
        let json = #"{"title":"Kris","baseURL":"/","analytics":{"umami":{"scriptUrl":"https://x/s.js","websiteId":"id","events":{"outboundLinks":true}}}}"#
        let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
        let events = try XCTUnwrap(config.analytics?.umami?.events)
        XCTAssertEqual(events.outboundLinks, true)
        XCTAssertNil(events.downloads)
        XCTAssertNil(events.themeElements)
        XCTAssertNil(events.downloadExtensions)
    }

    func testDecodesAnalyticsUmamiEventsInLocalBlock() throws {
        let json = """
        {
          "title": "Kris",
          "baseURL": "/",
          "analytics": {
            "umami": {
              "scriptUrl": "https://x/s.js",
              "websiteId": "id",
              "local": {
                "scriptUrl": "http://localhost:3000/script.js",
                "websiteId": "local-456",
                "events": { "downloads": true }
              }
            }
          }
        }
        """
        let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
        let local = try XCTUnwrap(config.analytics?.umami?.local)
        XCTAssertEqual(local.events?.downloads, true)
        // Events on the prod block stay independent of the local override.
        XCTAssertNil(config.analytics?.umami?.events)
    }

    func testLegacyConfigWithoutAnalyticsDecodes() throws {
        let json = #"{"title":"Kris","baseURL":"/"}"#
        let config = try JSONDecoder().decode(SiteConfig.self, from: Data(json.utf8))
        XCTAssertNil(config.analytics)
    }
}
