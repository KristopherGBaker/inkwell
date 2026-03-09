import Foundation

public final class PreviewWatcher {
    private let paths: [URL]
    private var excludedPaths: [URL]
    private let pollInterval: TimeInterval
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "inkwell.preview-watcher")
    private let lock = NSLock()
    private var timer: DispatchSourceTimer?
    private var lastSnapshot = ""

    public init(paths: [URL], excludedPaths: [URL] = [], pollInterval: TimeInterval = 0.5, onChange: @escaping () -> Void) {
        self.paths = paths
        self.excludedPaths = excludedPaths.map { $0.standardizedFileURL }
        self.pollInterval = pollInterval
        self.onChange = onChange
    }

    public func start() {
        lock.lock()
        if timer != nil {
            lock.unlock()
            return
        }
        lock.unlock()

        let initialSnapshot = snapshot()

        lock.lock()
        if timer != nil {
            lock.unlock()
            return
        }
        lastSnapshot = initialSnapshot
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
        timer.setEventHandler { [weak self] in
            self?.poll()
        }
        self.timer = timer
        lock.unlock()

        timer.resume()
    }

    public func stop() {
        lock.lock()
        let timer = self.timer
        self.timer = nil
        lock.unlock()

        timer?.cancel()
    }

    public func updateExcludedPaths(_ excludedPaths: [URL]) {
        lock.lock()
        self.excludedPaths = excludedPaths.map { $0.standardizedFileURL }
        lock.unlock()
    }

    public func refreshBaseline() {
        let currentSnapshot = snapshot()

        lock.lock()
        if timer != nil {
            lastSnapshot = currentSnapshot
        }
        lock.unlock()
    }

    private func poll() {
        let nextSnapshot = snapshot()
        var didChange = false

        lock.lock()
        if timer != nil, nextSnapshot != lastSnapshot {
            lastSnapshot = nextSnapshot
            didChange = true
        }
        lock.unlock()

        if didChange {
            onChange()
        }
    }

    private func snapshot() -> String {
        var entries: [String] = []
        let fileManager = FileManager.default
        let excludedPaths = currentExcludedPaths()

        for path in paths {
            let standardized = path.standardizedFileURL
            if isExcluded(standardized, excludedPaths: excludedPaths) {
                continue
            }
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: standardized.path, isDirectory: &isDirectory) else {
                entries.append("missing:\(standardized.path)")
                continue
            }

            if isDirectory.boolValue {
                entries.append(contentsOf: directoryEntries(at: standardized, fileManager: fileManager, excludedPaths: excludedPaths))
            } else {
                entries.append(fileEntry(at: standardized, fileManager: fileManager))
            }
        }

        return entries.sorted().joined(separator: "\n")
    }

    private func directoryEntries(at url: URL, fileManager: FileManager, excludedPaths: [URL]) -> [String] {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else {
            return ["directory:\(url.path)"]
        }

        var entries: [String] = ["directory:\(url.path)"]
        for case let fileURL as URL in enumerator {
            if isExcluded(fileURL.standardizedFileURL, excludedPaths: excludedPaths) {
                enumerator.skipDescendants()
                continue
            }
            entries.append(fileEntry(at: fileURL, fileManager: fileManager))
        }
        return entries
    }

    private func currentExcludedPaths() -> [URL] {
        lock.lock()
        let excludedPaths = self.excludedPaths
        lock.unlock()

        return excludedPaths
    }

    private func isExcluded(_ url: URL, excludedPaths: [URL]) -> Bool {
        return excludedPaths.contains { excluded in
            url.path == excluded.path || url.path.hasPrefix(excluded.path + "/")
        }
    }

    private func fileEntry(at url: URL, fileManager: FileManager) -> String {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let modifiedAt = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        let fileSize = values?.fileSize ?? -1
        return "file:\(url.path):\(modifiedAt):\(fileSize)"
    }
}
