import Foundation

/// Detects `$inline$` and `$$block$$` math runs in markdown, swaps them for
/// placeholders that survive cmark's HTML rendering, and restitches the
/// rendered katex HTML back into the final document.
///
/// Detection rules (per RFC 2026-05-05):
/// - Inline `$x$`: opening `$` is immediately followed by non-whitespace,
///   closing `$` is immediately preceded by non-whitespace, and the closing
///   `$` is not followed by a digit (false-positive guard for prices like
///   `$5 and $10`).
/// - Block `$$...$$`: opening `$$` and closing `$$` each occupy their own
///   line (after optional leading whitespace).
/// - Math is never extracted from inside fenced code blocks or inline code
///   spans.
public struct MathEngine {
    public init() {}

    public struct MathRun: Equatable, Sendable {
        public let id: Int
        public let source: String
        public let isBlock: Bool

        public init(id: Int, source: String, isBlock: Bool) {
            self.id = id
            self.source = source
            self.isBlock = isBlock
        }
    }

    public struct ExtractResult: Equatable, Sendable {
        public let markdown: String
        public let runs: [MathRun]

        public var hasMath: Bool { runs.isEmpty == false }
    }

    public func extract(markdown: String) -> ExtractResult {
        guard markdown.contains("$") else {
            return ExtractResult(markdown: markdown, runs: [])
        }

        var runs: [MathRun] = []
        var output: [String] = []
        let lines = markdown.components(separatedBy: "\n")
        var inFence = false
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                inFence.toggle()
                output.append(line)
                i += 1
                continue
            }
            if inFence {
                output.append(line)
                i += 1
                continue
            }

            if trimmed == "$$" {
                var bodyLines: [String] = []
                var scan = i + 1
                var foundClose = false
                while scan < lines.count {
                    if lines[scan].trimmingCharacters(in: .whitespaces) == "$$" {
                        foundClose = true
                        break
                    }
                    bodyLines.append(lines[scan])
                    scan += 1
                }
                if foundClose {
                    let id = runs.count
                    let run = MathRun(id: id, source: bodyLines.joined(separator: "\n"), isBlock: true)
                    runs.append(run)
                    output.append(placeholder(for: run))
                    i = scan + 1
                    continue
                }
            }

            output.append(processInlineMath(line: line, runs: &runs))
            i += 1
        }

        return ExtractResult(markdown: output.joined(separator: "\n"), runs: runs)
    }

    /// Builds the placeholder HTML element for a math run. Custom element
    /// name keeps cmark and downstream HTML processors from touching it.
    /// Calls scripts/render-math.mjs to render runs to katex HTML. Returns
    /// `[runId: html]`. Returns an empty dict if Node or katex aren't
    /// available — callers should treat that as graceful degradation.
    public func renderViaNode(runs: [MathRun], scriptDirectory: URL) -> [Int: String] {
        guard runs.isEmpty == false else { return [:] }

        struct Payload: Encodable {
            let id: Int
            let source: String
            let isBlock: Bool
        }
        let payload = runs.map { Payload(id: $0.id, source: $0.source, isBlock: $0.isBlock) }
        let encoder = JSONEncoder()
        guard let json = try? encoder.encode(payload) else { return [:] }
        let encoded = json.base64EncodedString()
        let script = scriptDirectory.appendingPathComponent("render-math.mjs")
        guard let data = NodeRunner().run(script: script, args: [encoded]),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }

        var result: [Int: String] = [:]
        for (key, html) in parsed {
            if let id = Int(key) {
                result[id] = html
            }
        }
        return result
    }

    public func placeholder(for run: MathRun) -> String {
        let kind = run.isBlock ? "block" : "inline"
        return "<x-math-placeholder data-id=\"\(run.id)\" data-kind=\"\(kind)\"></x-math-placeholder>"
    }

    /// Replaces math placeholders in `html` with rendered katex HTML, wrapped
    /// in `<span class="math math-inline">` (inline) or
    /// `<div class="math math-block">` (block). Falls back to the raw source
    /// when no rendered HTML is available for a given run id.
    public func restitch(html: String, runs: [MathRun], renderedHTML: [Int: String]) -> String {
        var output = html
        for run in runs {
            let needle = placeholder(for: run)
            let payload = renderedHTML[run.id] ?? escapeHTML(run.source)
            let replacement: String
            if run.isBlock {
                replacement = "<div class=\"math math-block\">\(payload)</div>"
            } else {
                replacement = "<span class=\"math math-inline\">\(payload)</span>"
            }
            output = output.replacingOccurrences(of: needle, with: replacement)
        }
        return output
    }

    // MARK: - Inline scanner

    private func processInlineMath(line: String, runs: inout [MathRun]) -> String {
        guard line.contains("$") else { return line }

        var result = ""
        let chars = Array(line)
        var i = 0

        while i < chars.count {
            let char = chars[i]

            if char == "`" {
                if let closingIndex = findInlineCodeClose(chars, from: i + 1) {
                    result.append(contentsOf: chars[i...closingIndex])
                    i = closingIndex + 1
                    continue
                }
                result.append(char)
                i += 1
                continue
            }

            if char == "$", let match = matchInlineMath(in: chars, openAt: i) {
                let id = runs.count
                let run = MathRun(id: id, source: match.source, isBlock: false)
                runs.append(run)
                result.append(placeholder(for: run))
                i = match.endIndex
                continue
            }

            result.append(char)
            i += 1
        }

        return result
    }

    private func findInlineCodeClose(_ chars: [Character], from start: Int) -> Int? {
        var i = start
        while i < chars.count {
            if chars[i] == "`" { return i }
            i += 1
        }
        return nil
    }

    private struct InlineMathMatch {
        let source: String
        let endIndex: Int
    }

    private func matchInlineMath(in chars: [Character], openAt: Int) -> InlineMathMatch? {
        let next = openAt + 1
        guard next < chars.count else { return nil }
        let firstInside = chars[next]
        guard firstInside.isWhitespace == false, firstInside != "$" else { return nil }

        var scan = next
        while scan < chars.count {
            if chars[scan] == "$" {
                guard scan > next else {
                    scan += 1
                    continue
                }
                let prev = chars[scan - 1]
                if prev.isWhitespace { return nil }
                let after = (scan + 1 < chars.count) ? chars[scan + 1] : nil
                if let after, after.isNumber { return nil }
                let source = String(chars[next..<scan])
                return InlineMathMatch(source: source, endIndex: scan + 1)
            }
            scan += 1
        }
        return nil
    }

    private func escapeHTML(_ input: String) -> String {
        input
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
