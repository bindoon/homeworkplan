import SwiftUI

enum AgentMarkdownParser {
    static func preprocessLineBreaks(in markdown: String) -> String {
        var result = ""
        var inCodeBlock = false
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        for (index, line) in lines.enumerated() {
            if index > 0 {
                let previousLine = lines[index - 1]
                if inCodeBlock {
                    result += "\n"
                } else if line.isEmpty || previousLine.isEmpty {
                    result += "\n"
                } else if isMarkdownStructuralLine(line) || isMarkdownStructuralLine(previousLine) {
                    result += "\n"
                } else {
                    result += "  \n"
                }
            }

            if line.trimmingCharacters(in: CharacterSet.whitespaces).hasPrefix("```") {
                inCodeBlock.toggle()
            }
            result += line
        }

        return result
    }

    static func attributedString(from markdown: String) -> AttributedString? {
        let processed = preprocessLineBreaks(in: markdown)
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .full
        options.failurePolicy = .returnPartiallyParsedIfPossible
        return try? AttributedString(markdown: processed, options: options)
    }

    private static func isMarkdownStructuralLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
        if trimmed.isEmpty { return true }
        if trimmed.hasPrefix("#") { return true }
        if trimmed.hasPrefix(">") { return true }
        if trimmed.hasPrefix("```") { return true }
        if trimmed.hasPrefix("- ")
            || trimmed.hasPrefix("* ")
            || trimmed.hasPrefix("+ ")
            || trimmed.hasPrefix("- [")
            || trimmed.hasPrefix("* [") {
            return true
        }
        if let dotIndex = trimmed.firstIndex(of: "."),
           dotIndex > trimmed.startIndex,
           trimmed[..<dotIndex].allSatisfy(\.isNumber),
           trimmed.index(after: dotIndex) < trimmed.endIndex,
           trimmed[trimmed.index(after: dotIndex)] == " " {
            return true
        }
        return false
    }
}

struct AgentMarkdownText: View {
    let text: String
    var isStreaming: Bool = false

    var body: some View {
        renderedText
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .font(.body)
    }

    @ViewBuilder
    private var renderedText: some View {
        if text.isEmpty, isStreaming {
            Text("思考中…") + streamingCursor
        } else if let attributed = AgentMarkdownParser.attributedString(from: text) {
            if isStreaming {
                Text(attributed) + streamingCursor
            } else {
                Text(attributed)
            }
        } else if isStreaming {
            Text(text) + streamingCursor
        } else {
            Text(text)
        }
    }

    private var streamingCursor: Text {
        Text("▍").foregroundStyle(.secondary)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        AgentMarkdownText(
            text: """
            **今日待办**
            - 数学：练习册 P10
            - 英语：抄写第三课

            点击确认卡片后才会写入。
            """
        )
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))

        AgentMarkdownText(
            text: """
            第一行
            第二行
            """,
            isStreaming: true
        )
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    .padding()
}
