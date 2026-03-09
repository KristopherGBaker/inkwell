import Foundation
import XCTest
@testable import BlogPreview

final class PreviewWatcherTests: XCTestCase {
    func testDetectsChangesInWatchedDirectory() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("post.md")
        try "first".write(to: file, atomically: true, encoding: .utf8)

        let changeDetected = expectation(description: "change detected")
        let watcher = PreviewWatcher(paths: [root], pollInterval: 0.1) {
            changeDetected.fulfill()
        }

        watcher.start()
        defer { watcher.stop() }

        Thread.sleep(forTimeInterval: 0.2)
        try "second".write(to: file, atomically: true, encoding: .utf8)

        wait(for: [changeDetected], timeout: 2.0)
    }

    func testDoesNotFireWithoutChanges() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "first".write(to: root.appendingPathComponent("post.md"), atomically: true, encoding: .utf8)

        let inverted = expectation(description: "no change")
        inverted.isInverted = true
        let watcher = PreviewWatcher(paths: [root], pollInterval: 0.1) {
            inverted.fulfill()
        }

        watcher.start()
        defer { watcher.stop() }

        wait(for: [inverted], timeout: 0.5)
    }

    func testDetectsChangesInHiddenFiles() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".drafts"), withIntermediateDirectories: true)
        let file = root.appendingPathComponent(".drafts/post.md")
        try "first".write(to: file, atomically: true, encoding: .utf8)

        let changeDetected = expectation(description: "hidden change detected")
        let watcher = PreviewWatcher(paths: [root], pollInterval: 0.1) {
            changeDetected.fulfill()
        }

        watcher.start()
        defer { watcher.stop() }

        Thread.sleep(forTimeInterval: 0.2)
        try "second".write(to: file, atomically: true, encoding: .utf8)

        wait(for: [changeDetected], timeout: 2.0)
    }

    func testCanStopWatcherFromChangeHandler() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("post.md")
        try "first".write(to: file, atomically: true, encoding: .utf8)

        let stopped = expectation(description: "watcher stopped from callback")
        var watcher: PreviewWatcher?
        watcher = PreviewWatcher(paths: [root], pollInterval: 0.1) {
            watcher?.stop()
            stopped.fulfill()
        }

        watcher?.start()
        Thread.sleep(forTimeInterval: 0.2)
        try "second".write(to: file, atomically: true, encoding: .utf8)

        wait(for: [stopped], timeout: 2.0)
    }

    func testIgnoresChangesInsideExcludedOutputDirectory() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let publicRoot = root.appendingPathComponent("public")
        let outputRoot = publicRoot.appendingPathComponent("site")
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        let generatedFile = outputRoot.appendingPathComponent("index.html")
        try "first".write(to: generatedFile, atomically: true, encoding: .utf8)

        let inverted = expectation(description: "excluded output change")
        inverted.isInverted = true
        let watcher = PreviewWatcher(paths: [publicRoot], excludedPaths: [outputRoot], pollInterval: 0.1) {
            inverted.fulfill()
        }

        watcher.start()
        defer { watcher.stop() }

        Thread.sleep(forTimeInterval: 0.2)
        try "second".write(to: generatedFile, atomically: true, encoding: .utf8)

        wait(for: [inverted], timeout: 0.5)
    }

    func testRefreshBaselineIgnoresGeneratedChangesInWatchedPublicRoot() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let sourceFile = root.appendingPathComponent("post.md")
        let generatedFile = root.appendingPathComponent("index.html")
        try "draft".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "first".write(to: generatedFile, atomically: true, encoding: .utf8)

        let rebuilt = expectation(description: "source change rebuild")
        let inverted = expectation(description: "generated change after refresh")
        inverted.isInverted = true
        var changeCount = 0
        var watcher: PreviewWatcher?
        watcher = PreviewWatcher(paths: [root], pollInterval: 0.1) {
            changeCount += 1
            if changeCount == 1 {
                try? "second".write(to: generatedFile, atomically: true, encoding: .utf8)
                watcher?.refreshBaseline()
                rebuilt.fulfill()
            } else {
                inverted.fulfill()
            }
        }

        watcher?.start()
        defer { watcher?.stop() }

        Thread.sleep(forTimeInterval: 0.2)
        try "published".write(to: sourceFile, atomically: true, encoding: .utf8)

        wait(for: [rebuilt], timeout: 2.0)
        wait(for: [inverted], timeout: 0.5)
    }
}
