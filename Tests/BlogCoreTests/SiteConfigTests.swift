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
}
