import SwiftUI

enum AgentMarkdownParser {
    static func normalizedMarkdown(_ markdown: String) -> String {
        markdown.replacingOccurrences(of: "\r\n", with: "\n")
    }

    static func attributedString(from markdown: String) -> AttributedString? {
        let normalized = normalizedMarkdown(markdown)
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        options.failurePolicy = .returnPartiallyParsedIfPossible
        return try? AttributedString(markdown: normalized, options: options)
    }
}

struct AgentMarkdownText: View {
    let text: String
    var isStreaming: Bool = false

    var body: some View {
        renderedText
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
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
            好的，已为你整理：

            **今日待办**
            - 数学：练习册 P10
            - 英语：抄写第三课

            确认后即可添加。
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
