import Foundation
import cmark

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public enum MarkdownRenderError: Error {
    case encodingFailed
}

public struct GFMEngine: MarkdownEngine {
    private let highlightScriptURL: URL?

    public init(highlightScriptURL: URL? = nil) {
        self.highlightScriptURL = highlightScriptURL
    }

    public func render(_ markdown: String) throws -> String {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var output: [String] = []
        var index = 0

        while index < lines.count {
            if let block = try renderCodeFence(lines, &index) { output.append(block); continue }
            if let block = renderTable(lines, &index) { output.append(block); continue }
            if let block = renderTaskList(lines, &index) { output.append(block); continue }
            if let block = try renderAlert(lines, &index) { output.append(block); continue }
            if lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }
            output.append(try renderParagraph(lines, &index))
        }

        return output.joined(separator: "\n")
    }

    /// Renders a fenced code block at `index`, advancing past the closing fence.
    /// Returns nil if the current line does not open a fence.
    private func renderCodeFence(_ lines: [String], _ index: inout Int) throws -> String? {
        guard lines[index].hasPrefix("```") else { return nil }
        let language = lines[index].replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespaces)
        index += 1
        var code: [String] = []
        var foundClosing = false
        while index < lines.count {
            if lines[index].hasPrefix("```") {
                foundClosing = true
                break
            }
            code.append(lines[index])
            index += 1
        }
        guard foundClosing else { throw MarkdownRenderError.encodingFailed }
        index += 1
        let source = code.joined(separator: "\n")
        if isMermaidLanguage(language) {
            return "<pre class=\"mermaid\">\(escapeHTML(source))</pre>"
        }
        if let highlighted = highlightWithShiki(code: source, language: language) {
            return highlighted
        }
        let languageClass = language.isEmpty ? "" : " class=\"language-\(language)\""
        return "<pre><code\(languageClass)>\(escapeHTML(source))</code></pre>"
    }

    /// Renders a pipe table starting at `index`, advancing past header/divider/row.
    /// Returns nil if the current line does not begin a table.
    private func renderTable(_ lines: [String], _ index: inout Int) -> String? {
        guard isTableHeader(lines, at: index) else { return nil }
        let headers = parseTableCells(lines[index])
        let rows = parseTableCells(lines[index + 2])
        index += 3
        let head = headers.map { "<th>\(inline($0))</th>" }.joined()
        let body = rows.map { "<td>\(inline($0))</td>" }.joined()
        return "<table><thead><tr>\(head)</tr></thead><tbody><tr>\(body)</tr></tbody></table>"
    }

    /// Renders a run of GitHub task-list items, advancing past the consumed lines.
    /// Returns nil if the current line is not a task-list item.
    private func renderTaskList(_ lines: [String], _ index: inout Int) -> String? {
        guard lines[index].hasPrefix("- [") else { return nil }
        var items: [String] = []
        while index < lines.count, lines[index].hasPrefix("- [") {
            let item = lines[index]
            let checked = item.contains("[x]") || item.contains("[X]")
            let text = item.replacingOccurrences(of: "- [x] ", with: "")
                .replacingOccurrences(of: "- [X] ", with: "")
                .replacingOccurrences(of: "- [ ] ", with: "")
            let mark = checked ? " checked" : ""
            items.append("<li><input type=\"checkbox\" disabled\(mark)> \(inline(text))</li>")
            index += 1
        }
        return "<ul class=\"task-list\">\(items.joined())</ul>"
    }

    /// Renders a GitHub alert blockquote, advancing past its body lines.
    /// Returns nil if the current line does not open an alert.
    private func renderAlert(_ lines: [String], _ index: inout Int) throws -> String? {
        guard let alert = parseAlertStart(lines[index]) else { return nil }
        index += 1
        var bodyLines: [String] = []
        while index < lines.count, lines[index].hasPrefix(">") {
            let raw = lines[index]
            let stripped = raw.hasPrefix("> ") ? String(raw.dropFirst(2)) : String(raw.dropFirst())
            bodyLines.append(stripped)
            index += 1
        }
        let bodyMarkdown = bodyLines.joined(separator: "\n")
        let renderedBody = try renderWithCMark(bodyMarkdown).trimmingCharacters(in: .whitespacesAndNewlines)
        return "<aside class=\"alert alert-\(alert.type)\">"
            + "<p class=\"alert-title\">\(alert.label)</p>\(renderedBody)</aside>"
    }

    /// Renders a paragraph by consuming contiguous non-block lines through cmark.
    private func renderParagraph(_ lines: [String], _ index: inout Int) throws -> String {
        var paragraphLines: [String] = []
        while index < lines.count,
              !lines[index].trimmingCharacters(in: .whitespaces).isEmpty,
              !lines[index].hasPrefix("```") &&
              !lines[index].hasPrefix("- [") &&
              !isTableHeader(lines, at: index) {
            paragraphLines.append(lines[index])
            index += 1
        }
        let paragraphMarkdown = applyStrikethroughHTML(paragraphLines.joined(separator: "\n"))
        return try renderWithCMark(paragraphMarkdown).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func renderWithCMark(_ markdown: String) throws -> String {
        guard let bytes = markdown.data(using: .utf8) else {
            throw MarkdownRenderError.encodingFailed
        }

        let htmlPtr: UnsafeMutablePointer<CChar>? = bytes.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress?.assumingMemoryBound(to: CChar.self) else {
                return nil
            }
            return cmark_markdown_to_html(base, rawBuffer.count, CMARK_OPT_UNSAFE)
        }

        guard let htmlPtr else { return "" }
        defer { free(htmlPtr) }
        return String(cString: htmlPtr)
    }

    private func inline(_ text: String) -> String {
        applyStrikethroughHTML(escapeHTML(text))
    }

    private func applyStrikethroughHTML(_ text: String) -> String {
        var value = text
        while let start = value.range(of: "~~"),
              let end = value.range(of: "~~", range: start.upperBound..<value.endIndex) {
            let inner = String(value[start.upperBound..<end.lowerBound])
            value.replaceSubrange(start.lowerBound..<end.upperBound, with: "<del>\(inner)</del>")
        }
        return value
    }

    private func isTableHeader(_ lines: [String], at index: Int) -> Bool {
        guard index + 2 < lines.count else { return false }
        let header = lines[index]
        let divider = lines[index + 1]
        let row = lines[index + 2]
        let dividerIsRule = divider
            .replacingOccurrences(of: "|", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-: "))
            .isEmpty
        return header.contains("|") && dividerIsRule && row.contains("|")
    }

    private func parseTableCells(_ line: String) -> [String] {
        line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func escapeHTML(_ input: String) -> String {
        input
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func parseAlertStart(_ line: String) -> (type: String, label: String)? {
        let prefix = "> [!"
        guard line.hasPrefix(prefix), let closing = line.firstIndex(of: "]") else {
            return nil
        }
        let start = line.index(line.startIndex, offsetBy: prefix.count)
        guard start < closing else { return nil }
        let rawType = String(line[start..<closing]).lowercased()
        let allowed = ["note", "tip", "important", "warning", "caution"]
        guard allowed.contains(rawType) else { return nil }
        return (type: rawType, label: rawType.uppercased())
    }

    private func isMermaidLanguage(_ language: String) -> Bool {
        language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "mermaid"
    }

    private func highlightWithShiki(code: String, language: String) -> String? {
        let encoded = Data(code.utf8).base64EncodedString()
        let args = [language.isEmpty ? "text" : language, encoded]

        for script in highlightScriptCandidates() {
            guard let data = NodeRunner().run(script: script, args: args),
                  let html = String(data: data, encoding: .utf8),
                  !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            return html
        }

        return nil
    }

    private func highlightScriptCandidates() -> [URL] {
        if let highlightScriptURL {
            return [highlightScriptURL]
        }

        let cwdScript = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("scripts/highlight-code.mjs")
            .standardizedFileURL

        let sourceCheckoutScript = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/highlight-code.mjs")
            .standardizedFileURL

        var seen = Set<String>()
        return [cwdScript, sourceCheckoutScript].filter { candidate in
            seen.insert(candidate.path).inserted
        }
    }
}
