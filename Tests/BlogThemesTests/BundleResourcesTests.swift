import Foundation
import XCTest
@testable import BlogThemes

final class BundleResourcesTests: XCTestCase {
    func testFindsThemesInFlatSwiftPMBundle() throws {
        let bundle = try makeBundle(themesPath: "themes")

        XCTAssertEqual(BundleResources.resourceRootURL(for: bundle), bundle)
    }

    func testFindsThemesInMacOSStyleBundleResourcesDirectory() throws {
        let bundle = try makeBundle(themesPath: "Contents/Resources/themes")

        XCTAssertEqual(
            BundleResources.resourceRootURL(for: bundle),
            bundle.appendingPathComponent("Contents/Resources")
        )
    }

    func testRejectsBundleWithoutThemes() throws {
        let bundle = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)

        XCTAssertNil(BundleResources.resourceRootURL(for: bundle))
    }

    private func makeBundle(themesPath: String) throws -> URL {
        let bundle = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(
            at: bundle.appendingPathComponent(themesPath),
            withIntermediateDirectories: true
        )
        return bundle
    }
}
