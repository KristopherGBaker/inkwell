import Foundation
import Vapor

public enum PreviewServerError: Error {
    case directoryNotFound(String)
}

public final class PreviewServer: @unchecked Sendable {
    private let rootLock = NSLock()
    private var rootStorage: URL
    public let port: Int
    private let liveReloadEnabled: Bool
    private let liveReloadBroker = LiveReloadBroker()

    public init(root: URL = URL(fileURLWithPath: "."), port: Int = 8000, liveReloadEnabled: Bool = false) {
        self.rootStorage = root
        self.port = port
        self.liveReloadEnabled = liveReloadEnabled
    }

    public var root: URL {
        rootLock.lock()
        defer { rootLock.unlock() }
        return rootStorage
    }

    public func start() throws {
        guard FileManager.default.fileExists(atPath: root.path) else {
            throw PreviewServerError.directoryNotFound(root.path)
        }

        let app = Application(.init(name: "development", arguments: Self.environmentArguments()))
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = port
        if usesFileMiddleware {
            app.middleware.use(FileMiddleware(publicDirectory: root.path))
        }

        app.get { req async throws in
            return try self.response(for: self.root.appendingPathComponent("index.html").path, on: req)
        }

        if let liveReloadEndpointPath {
            app.on(.GET, [PathComponent(stringLiteral: liveReloadEndpointPath)]) { req in
                Response(
                    status: .ok,
                    headers: HTTPHeaders([
                        ("Content-Type", "text/event-stream"),
                        ("Cache-Control", "no-cache"),
                        ("Connection", "keep-alive")
                    ]),
                    body: .init(stream: { [liveReloadBroker = self.liveReloadBroker] writer in
                        _ = liveReloadBroker.addClient(writer: writer, on: req.eventLoop)
                    })
                )
            }
        }

        app.get(.catchall) { req async throws in
            let path = req.parameters.getCatchall().joined(separator: "/")
            guard let filePath = self.resolvedFilePath(for: path) else {
                throw Abort(.notFound)
            }
            return try self.response(for: filePath, on: req)
        }

        print("Preview available at http://localhost:\(port) (serving \(root.path))")
        defer {
            liveReloadBroker.shutdown()
            app.shutdown()
        }
        try app.run()
    }

    public func triggerReload() {
        liveReloadBroker.triggerReload()
    }

    public func updateRoot(to root: URL) {
        rootLock.lock()
        rootStorage = root
        rootLock.unlock()
    }

    func resolvedFilePath(for requestPath: String) -> String? {
        let cleanedPath = requestPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if cleanedPath.isEmpty {
            let rootIndex = root.appendingPathComponent("index.html")
            return FileManager.default.fileExists(atPath: rootIndex.path) ? rootIndex.path : nil
        }

        let components = cleanedPath.split(separator: "/").map(String.init)
        if components.contains(where: { $0 == ".." }) {
            return nil
        }

        let candidate = components.reduce(root) { partial, next in
            partial.appendingPathComponent(next)
        }

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                let directoryIndex = candidate.appendingPathComponent("index.html")
                return FileManager.default.fileExists(atPath: directoryIndex.path) ? directoryIndex.path : nil
            }
            return candidate.path
        }

        if !candidate.pathExtension.isEmpty {
            return nil
        }

        let htmlCandidate = candidate.appendingPathExtension("html")
        return FileManager.default.fileExists(atPath: htmlCandidate.path) ? htmlCandidate.path : nil
    }

    func injectLiveReloadScript(into html: String) -> String {
        guard liveReloadEnabled else {
            return html
        }

        guard let range = html.range(of: "</body>", options: [.caseInsensitive, .backwards]) else {
            return html + "<script>\(LiveReloadScript.snippet)</script>"
        }

        return html.replacingCharacters(in: range, with: "<script>\(LiveReloadScript.snippet)</script></body>")
    }

    var liveReloadEndpointPath: String? {
        guard liveReloadEnabled else {
            return nil
        }

        return String(LiveReloadScript.path.dropFirst())
    }

    var usesFileMiddleware: Bool {
        !liveReloadEnabled
    }

    static func environmentArguments(executablePath: String? = nil) -> [String] {
        [executablePath ?? ProcessInfo.processInfo.arguments.first ?? "preview"]
    }

    private func response(for filePath: String, on req: Request) throws -> Response {
        if liveReloadEnabled, URL(fileURLWithPath: filePath).pathExtension.lowercased() == "html" {
            let html = try String(contentsOfFile: filePath, encoding: .utf8)
            let body = injectLiveReloadScript(into: html)
            return Response(
                status: .ok,
                headers: HTTPHeaders([("Content-Type", "text/html; charset=utf-8")]),
                body: .init(string: body)
            )
        }

        return req.fileio.streamFile(at: filePath)
    }
}

final class LiveReloadBroker: @unchecked Sendable {
    private struct Client {
        let writer: BodyStreamWriter
        let completion: EventLoopPromise<Void>
    }

    private let lock = NSLock()
    private var clients: [UUID: Client] = [:]

    func addClient(writer: BodyStreamWriter, on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        addClient(on: eventLoop) { promise in
            Client(writer: writer, completion: promise)
        }
    }

    func registerClientForTesting(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        addClient(on: eventLoop) { promise in
            Client(writer: NullBodyStreamWriter(eventLoop: eventLoop), completion: promise)
        }
    }

    private func addClient(on eventLoop: EventLoop, makeClient: (EventLoopPromise<Void>) -> Client) -> EventLoopFuture<Void> {
        let id = UUID()
        let promise = eventLoop.makePromise(of: Void.self)
        let client = makeClient(promise)

        lock.lock()
        clients[id] = client
        lock.unlock()

        promise.futureResult.whenComplete { [weak self] _ in
            self?.removeClient(id: id)
        }
        return promise.futureResult
    }

    func triggerReload() {
        let clients = takeClients()

        for client in clients.values {
            var buffer = ByteBufferAllocator().buffer(capacity: 16)
            buffer.writeString("data: reload\n\n")
            // Always send .end after the data buffer (using whenComplete instead
            // of flatMap) so a failed buffer write — e.g. the SSE channel has
            // already been closed by the browser — doesn't skip the end-of-stream
            // signal, which would trip Vapor's deinit assertion on the writer.
            client.writer.write(.buffer(buffer)).whenComplete { _ in
                client.writer.write(.end).whenComplete { _ in
                    client.completion.succeed(())
                }
            }
        }
    }

    func shutdown() {
        let clients = takeClients()

        // Block until every writer has processed .end. Without this wait,
        // app.shutdown() can begin tearing down the eventLoops before the
        // queued .end writes are processed, causing the writer to deinit with
        // isComplete=false and trip the debug-build assertion in
        // HTTPServerResponseEncoder.
        for client in clients.values {
            do {
                try client.writer.write(.end).wait()
            } catch {
                // Channel may already be closed; isComplete is still set
                // synchronously inside Vapor's writer, so the deinit assertion
                // is satisfied either way.
            }
            client.completion.succeed(())
        }
    }

    var clientCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return clients.count
    }

    private func takeClients() -> [UUID: Client] {
        lock.lock()
        let clients = self.clients
        self.clients.removeAll()
        lock.unlock()
        return clients
    }

    private func removeClient(id: UUID) {
        lock.lock()
        clients.removeValue(forKey: id)
        lock.unlock()
    }
}

private struct NullBodyStreamWriter: BodyStreamWriter {
    let eventLoop: EventLoop

    func write(_ result: BodyStreamResult, promise: EventLoopPromise<Void>?) {
        promise?.succeed(())
    }
}
