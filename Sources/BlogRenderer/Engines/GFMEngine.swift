import Foundation

public enum MarkdownRenderError: Error {
    case malformedFence
}

public struct GFMEngine: MarkdownEngine {
    public init() {}

    public func render(_ markdown: String) throws -> String {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var i = 0
        var output: [String] = []

        while i < lines.count {
            let line = lines[i]

            if line.hasPrefix("```") {
                let language = line.replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespaces)
                i += 1
                var code: [String] = []
                var foundClosing = false
                while i < lines.count {
                    let codeLine = lines[i]
                    if codeLine.hasPrefix("```") {
                        foundClosing = true
                        break
                    }
                    code.append(codeLine)
                    i += 1
                }
                guard foundClosing else { throw MarkdownRenderError.malformedFence }
                let escaped = escapeHTML(code.joined(separator: "\n"))
                let languageClass = language.isEmpty ? "" : " class=\"language-\(language)\""
                output.append("<pre><code\(languageClass)>\(escaped)</code></pre>")
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

            if line.hasPrefix("- [") {
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

            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                i += 1
                continue
            }

            output.append("<p>\(inline(line))</p>")
            i += 1
        }

        return output.joined(separator: "\n")
    }

    private func inline(_ text: String) -> String {
        var value = escapeHTML(text)
        while let start = value.range(of: "~~"), let end = value.range(of: "~~", range: start.upperBound..<value.endIndex) {
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
}
