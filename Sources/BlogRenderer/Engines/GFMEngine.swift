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
    public init() {}

    public func render(_ markdown: String) throws -> String {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var output: [String] = []
        var i = 0

        while i < lines.count {
            if lines[i].hasPrefix("```") {
                let language = lines[i].replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespaces)
                i += 1
                var code: [String] = []
                var foundClosing = false
                while i < lines.count {
                    if lines[i].hasPrefix("```") {
                        foundClosing = true
                        break
                    }
                    code.append(lines[i])
                    i += 1
                }
                guard foundClosing else { throw MarkdownRenderError.encodingFailed }
                let source = code.joined(separator: "\n")
                if isMermaidLanguage(language) {
                    output.append("<pre class=\"mermaid\">\(escapeHTML(source))</pre>")
                } else if let highlighted = highlightWithShiki(code: source, language: language) {
                    output.append(highlighted)
                } else {
                    let languageClass = language.isEmpty ? "" : " class=\"language-\(language)\""
                    output.append("<pre><code\(languageClass)>\(escapeHTML(source))</code></pre>")
                }
                i += 1
                continue
            }

            if isTableHeader(lines, at: i) {
                let headers = parseTableCells(lines[i])
                let rows = parseTableCells(lines[i + 2])
                output.append("<table><thead><tr>\(headers.map { "<th>\(inline($0))</th>" }.joined())</tr></thead><tbody><tr>\(rows.map { "<td>\(inline($0))</td>" }.joined())</tr></tbody></table>")
                i += 3
                continue
            }

            if lines[i].hasPrefix("- [") {
                var items: [String] = []
                while i < lines.count, lines[i].hasPrefix("- [") {
                    let item = lines[i]
                    let checked = item.contains("[x]") || item.contains("[X]")
                    let text = item.replacingOccurrences(of: "- [x] ", with: "")
                        .replacingOccurrences(of: "- [X] ", with: "")
                        .replacingOccurrences(of: "- [ ] ", with: "")
                    let mark = checked ? " checked" : ""
                    items.append("<li><input type=\"checkbox\" disabled\(mark)> \(inline(text))</li>")
                    i += 1
                }
                output.append("<ul class=\"task-list\">\(items.joined())</ul>")
                continue
            }

            if let alert = parseAlertStart(lines[i]) {
                i += 1
                var bodyLines: [String] = []
                while i < lines.count, lines[i].hasPrefix(">") {
                    let raw = lines[i]
                    let stripped = raw.hasPrefix("> ") ? String(raw.dropFirst(2)) : String(raw.dropFirst())
                    bodyLines.append(stripped)
                    i += 1
                }

                let bodyMarkdown = bodyLines.joined(separator: "\n")
                let renderedBody = try renderWithCMark(bodyMarkdown).trimmingCharacters(in: .whitespacesAndNewlines)
                output.append("<aside class=\"alert alert-\(alert.type)\"><p class=\"alert-title\">\(alert.label)</p>\(renderedBody)</aside>")
                continue
            }

            if lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                i += 1
                continue
            }

            var paragraphLines: [String] = []
            while i < lines.count,
                  !lines[i].trimmingCharacters(in: .whitespaces).isEmpty,
                  !lines[i].hasPrefix("```") &&
                  !lines[i].hasPrefix("- [") &&
                  !isTableHeader(lines, at: i) {
                paragraphLines.append(lines[i])
                i += 1
            }
            let paragraphMarkdown = applyStrikethroughHTML(paragraphLines.joined(separator: "\n"))
            output.append(try renderWithCMark(paragraphMarkdown).trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return output.joined(separator: "\n")
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
        return header.contains("|") && divider.replacingOccurrences(of: "|", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "-: ")).isEmpty && row.contains("|")
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
        let script = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("scripts/highlight-code.mjs")
        let encoded = Data(code.utf8).base64EncodedString()
        let args = [language.isEmpty ? "text" : language, encoded]
        guard let data = NodeRunner().run(script: script, args: args),
              let html = String(data: data, encoding: .utf8),
              !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return html
    }
}
