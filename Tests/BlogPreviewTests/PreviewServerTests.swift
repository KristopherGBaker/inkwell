import Foundation
import XCTest
import Vapor
@testable import BlogPreview

final class PreviewServerTests: XCTestCase {
    func testResolvesDirectoryRouteToIndexFile() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("posts/welcome"), withIntermediateDirectories: true)
        try "ok".write(to: root.appendingPathComponent("posts/welcome/index.html"), atomically: true, encoding: .utf8)

        let server = PreviewServer(root: root, port: 8000)
        let resolved = server.resolvedFilePath(for: "posts/welcome/")

        XCTAssertEqual(resolved, root.appendingPathComponent("posts/welcome/index.html").path)
    }

    func testInjectsLiveReloadScriptBeforeClosingBodyTag() {
        let server = PreviewServer(root: URL(fileURLWithPath: "/tmp"), port: 8000, liveReloadEnabled: true)
        let html = "<html><body><h1>Hello</h1></body></html>"

        let result = server.injectLiveReloadScript(into: html)

        XCTAssertTrue(result.contains(LiveReloadScript.snippet))
        XCTAssertTrue(result.contains("<script>"))
        XCTAssertTrue(result.contains("</script></body>"))
    }

    func testLeavesHTMLWithoutBodyTagUnchanged() {
        let server = PreviewServer(root: URL(fileURLWithPath: "/tmp"), port: 8000, liveReloadEnabled: true)
        let html = "<html><h1>Hello</h1></html>"

        let result = server.injectLiveReloadScript(into: html)

        XCTAssertTrue(result.hasSuffix("<script>\(LiveReloadScript.snippet)</script>"))
        XCTAssertTrue(result.hasPrefix(html))
    }

    func testDoesNotExposeLiveReloadEndpointWhenDisabled() {
        let server = PreviewServer(root: URL(fileURLWithPath: "/tmp"), port: 8000)

        XCTAssertNil(server.liveReloadEndpointPath)
    }

    func testExposesLiveReloadEndpointWhenEnabled() {
        let server = PreviewServer(root: URL(fileURLWithPath: "/tmp"), port: 8000, liveReloadEnabled: true)

        XCTAssertEqual(server.liveReloadEndpointPath, "__live_reload")
    }

    func testDisablesFileMiddlewareWhenLiveReloadIsEnabled() {
        let server = PreviewServer(root: URL(fileURLWithPath: "/tmp"), port: 8000, liveReloadEnabled: true)

        XCTAssertFalse(server.usesFileMiddleware)
    }

    func testUsesFileMiddlewareWhenLiveReloadIsDisabled() {
        let server = PreviewServer(root: URL(fileURLWithPath: "/tmp"), port: 8000)

        XCTAssertTrue(server.usesFileMiddleware)
    }

    func testUpdateRootChangesServedDirectory() throws {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let oldRoot = temp.appendingPathComponent("docs-a")
        let newRoot = temp.appendingPathComponent("docs-b")
        try FileManager.default.createDirectory(at: oldRoot.appendingPathComponent("posts/welcome"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newRoot.appendingPathComponent("posts/welcome"), withIntermediateDirectories: true)
        try "old".write(to: oldRoot.appendingPathComponent("posts/welcome/index.html"), atomically: true, encoding: .utf8)
        try "new".write(to: newRoot.appendingPathComponent("posts/welcome/index.html"), atomically: true, encoding: .utf8)

        let server = PreviewServer(root: oldRoot, port: 8000, liveReloadEnabled: true)
        XCTAssertEqual(server.resolvedFilePath(for: "posts/welcome/"), oldRoot.appendingPathComponent("posts/welcome/index.html").path)

        server.updateRoot(to: newRoot)

        XCTAssertEqual(server.resolvedFilePath(for: "posts/welcome/"), newRoot.appendingPathComponent("posts/welcome/index.html").path)
    }

    func testLiveReloadBrokerRemovesClientsOnShutdown() throws {
        let broker = LiveReloadBroker()
        let eventLoop = EmbeddedEventLoop()

        let future = broker.registerClientForTesting(on: eventLoop)

        XCTAssertEqual(broker.clientCount, 1)

        broker.shutdown()

        XCTAssertEqual(broker.clientCount, 0)
        XCTAssertNoThrow(try future.wait())
    }

    func testTriggerReloadSendsEndToClientWriter() throws {
        let broker = LiveReloadBroker()
        let eventLoop = EmbeddedEventLoop()
        let writer = RecordingBodyStreamWriter(eventLoop: eventLoop)

        let future = broker.addClient(writer: writer, on: eventLoop)
        broker.triggerReload()

        XCTAssertNoThrow(try future.wait())
        let writes = writer.writes
        XCTAssertEqual(writes.count, 2, "Expected one buffer write and one end write, got \(writes.count)")
        guard case .end = writes.last else {
            XCTFail("Expected last write to be .end, got \(String(describing: writes.last))")
            return
        }
    }

    func testShutdownSendsEndToClientWriter() throws {
        let broker = LiveReloadBroker()
        let eventLoop = EmbeddedEventLoop()
        let writer = RecordingBodyStreamWriter(eventLoop: eventLoop)

        let future = broker.addClient(writer: writer, on: eventLoop)
        broker.shutdown()

        XCTAssertNoThrow(try future.wait())
        let writes = writer.writes
        XCTAssertFalse(writes.isEmpty, "Expected at least one write (.end) on shutdown")
        guard case .end = writes.last else {
            XCTFail("Expected last write to be .end, got \(String(describing: writes.last))")
            return
        }
    }

    func testEnvironmentArgumentsIgnoreServeFlags() {
        XCTAssertEqual(PreviewServer.environmentArguments(executablePath: "/usr/bin/inkwell"), ["/usr/bin/inkwell"])
    }
}

private final class RecordingBodyStreamWriter: BodyStreamWriter, @unchecked Sendable {
    let eventLoop: EventLoop
    private let lock = NSLock()
    private var captured: [BodyStreamResult] = []

    init(eventLoop: EventLoop) {
        self.eventLoop = eventLoop
    }

    func write(_ result: BodyStreamResult, promise: EventLoopPromise<Void>?) {
        lock.lock()
        captured.append(result)
        lock.unlock()
        promise?.succeed(())
    }

    var writes: [BodyStreamResult] {
        lock.lock()
        defer { lock.unlock() }
        return captured
    }
}
