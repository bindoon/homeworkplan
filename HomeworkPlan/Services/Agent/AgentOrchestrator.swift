import Foundation
import UIKit

@MainActor
final class AgentOrchestrator {
    static let maxToolRounds = 5

    private let toolExecutor: ToolExecutor
    private let subjectRepository: SubjectRepository
    private let keychainService: KeychainService
    private let llmService: AgentLLMService

    private(set) var conversationHistory: [AgentMessage] = []
    private(set) var pendingProposals: [AgentProposal] = []
    private(set) var uiTurns: [ConversationTurn] = []

    init(
        toolExecutor: ToolExecutor,
        subjectRepository: SubjectRepository,
        keychainService: KeychainService,
        llmService: AgentLLMService = .shared
    ) {
        self.toolExecutor = toolExecutor
        self.subjectRepository = subjectRepository
        self.keychainService = keychainService
        self.llmService = llmService
    }

    func sendUserMessage(_ text: String) async throws -> AgentTurn {
        try await sendUserMessage(text, attachment: nil, onUIUpdate: nil)
    }

    func sendUserMessage(
        _ text: String,
        attachment: UserMessageAttachment?,
        onUIUpdate: (() -> Void)? = nil
    ) async throws -> AgentTurn {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || attachment != nil else {
            return AgentTurn(messages: conversationHistory)
        }

        let displayText = buildUserDisplayText(text: trimmed, attachment: attachment)
        let llmContent = buildUserLLMContent(text: trimmed, attachment: attachment)

        let userMessage = AgentMessage(role: .user, content: llmContent)
        conversationHistory.append(userMessage)
        uiTurns.append(
            ConversationTurn(
                role: .user,
                text: displayText,
                attachedImage: attachment?.image
            )
        )
        onUIUpdate?()

        var turnProposals: [AgentProposal] = []
        var rounds = 0

        while rounds < Self.maxToolRounds {
            try Task.checkCancellation()
            rounds += 1

            guard let apiKey = resolveAPIKey() else {
                throw AgentOrchestratorError.missingAPIKey
            }

            let streamingTurnID = appendStreamingAssistantTurn(status: rounds == 1 ? "思考中…" : "继续处理…")
            onUIUpdate?()

            let subjects = (try? subjectRepository.fetchAll()) ?? []
            let llmMessages = buildLLMMessages(systemPrompt: AgentSystemPrompt.build(subjects: subjects))
            let turnID = streamingTurnID
            let refreshUI = onUIUpdate

            let response = try await llmService.chat(
                messages: llmMessages,
                tools: ToolRegistry.openAITools,
                apiKey: apiKey,
                onContentDelta: { content in
                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        self.updateStreamingTurn(id: turnID, text: content, isStreaming: true)
                        refreshUI?()
                    }
                }
            )

            if response.toolCalls.isEmpty {
                let reply = response.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "好的。"
                finalizeStreamingTurn(id: streamingTurnID, text: reply)
                onUIUpdate?()

                let assistantMessage = AgentMessage(role: .assistant, content: reply)
                conversationHistory.append(assistantMessage)
                return AgentTurn(messages: conversationHistory, proposals: turnProposals)
            }

            removeStreamingTurn(id: streamingTurnID)
            onUIUpdate?()

            let assistantMessage = AgentMessage(
                role: .assistant,
                content: response.content ?? "",
                toolCalls: response.toolCalls
            )
            conversationHistory.append(assistantMessage)

            for toolCall in response.toolCalls {
                try Task.checkCancellation()
                let statusTurnID = appendStreamingAssistantTurn(status: toolStatusMessage(for: toolCall.name))
                onUIUpdate?()

                let toolResult: String
                do {
                    let execution = try await toolExecutor.execute(
                        toolName: toolCall.name,
                        argumentsJSON: toolCall.argumentsJSON,
                        attachment: attachment
                    )
                    switch execution {
                    case .immediate(let json):
                        toolResult = json
                    case .proposal(let proposal):
                        pendingProposals.append(proposal)
                        turnProposals.append(proposal)
                        removeStreamingTurn(id: statusTurnID)
                        uiTurns.append(ConversationTurn(role: .assistant, text: proposal.summary, proposal: proposal))
                        onUIUpdate?()
                        toolResult = proposalToolResult(proposal)
                    }
                } catch {
                    toolResult = encodeError(error)
                }

                removeStreamingTurn(id: statusTurnID)
                onUIUpdate?()

                conversationHistory.append(
                    AgentMessage(role: .tool, content: toolResult, toolCallID: toolCall.id)
                )
            }
        }

        throw AgentOrchestratorError.maxToolRoundsExceeded
    }

    func confirmProposal(id: UUID) throws -> String {
        guard let index = pendingProposals.firstIndex(where: { $0.id == id }) else {
            throw AgentOrchestratorError.proposalNotFound
        }
        guard pendingProposals[index].status == .pending else {
            throw AgentOrchestratorError.proposalAlreadyHandled
        }

        let result = try toolExecutor.confirmProposal(pendingProposals[index])
        pendingProposals[index].status = .confirmed
        updateUITurnProposalStatus(id: id, status: .confirmed)

        let systemNote = AgentMessage(role: .assistant, content: result)
        conversationHistory.append(systemNote)
        uiTurns.append(ConversationTurn(role: .assistant, text: result))

        return result
    }

    func rejectProposal(id: UUID) {
        guard let index = pendingProposals.firstIndex(where: { $0.id == id }) else { return }
        guard pendingProposals[index].status == .pending else { return }

        pendingProposals[index].status = .rejected
        updateUITurnProposalStatus(id: id, status: .rejected)

        let message = "已取消：\(pendingProposals[index].summary)"
        conversationHistory.append(AgentMessage(role: .assistant, content: message))
        uiTurns.append(ConversationTurn(role: .assistant, text: message))
    }

    func clearConversation() {
        conversationHistory.removeAll()
        uiTurns.removeAll()
        pendingProposals.removeAll()
    }

    func finalizeCancellation(onUIUpdate: (() -> Void)? = nil) {
        uiTurns.removeAll { $0.isStreaming }

        let message = "已停止。"
        let alreadyStopped = uiTurns.last?.role == .assistant && uiTurns.last?.text == message
        if !alreadyStopped {
            uiTurns.append(ConversationTurn(role: .assistant, text: message))
            conversationHistory.append(AgentMessage(role: .assistant, content: message))
        }

        onUIUpdate?()
    }

    // MARK: - Private

    @discardableResult
    private func appendStreamingAssistantTurn(status: String) -> UUID {
        let turn = ConversationTurn(role: .assistant, text: status, isStreaming: true)
        uiTurns.append(turn)
        return turn.id
    }

    private func updateStreamingTurn(id: UUID, text: String, isStreaming: Bool) {
        guard let index = uiTurns.firstIndex(where: { $0.id == id }) else { return }
        uiTurns[index].text = text
        uiTurns[index].isStreaming = isStreaming
    }

    private func finalizeStreamingTurn(id: UUID, text: String) {
        guard let index = uiTurns.firstIndex(where: { $0.id == id }) else {
            uiTurns.append(ConversationTurn(role: .assistant, text: text))
            return
        }
        uiTurns[index].text = text
        uiTurns[index].isStreaming = false
    }

    private func removeStreamingTurn(id: UUID) {
        uiTurns.removeAll { $0.id == id }
    }

    private func toolStatusMessage(for toolName: String) -> String {
        switch toolName {
        case "import_from_text", "import_from_image":
            return "正在解析作业…"
        case "create_task":
            return "正在准备添加作业…"
        case "list_tasks", "list_subjects", "list_recurring_rules":
            return "正在查询…"
        default:
            return "正在执行操作…"
        }
    }

    private func buildUserDisplayText(text: String, attachment: UserMessageAttachment?) -> String {
        if attachment != nil {
            if text.isEmpty {
                return "[截图]"
            }
            return "\(text)\n[截图]"
        }
        return text
    }

    private func buildUserLLMContent(text: String, attachment: UserMessageAttachment?) -> String {
        guard let attachment else { return text }

        var parts: [String] = ["用户发送了一张作业截图。"]
        parts.append("本地 OCR 已提取以下文字（请使用 import_from_image 工具并传入 ocr_text，勿重复 OCR）：")
        parts.append("--- OCR 开始 ---")
        parts.append(attachment.ocrText)
        parts.append("--- OCR 结束 ---")
        if !text.isEmpty {
            parts.append("用户补充说明：\(text)")
        }
        return parts.joined(separator: "\n")
    }

    private func buildLLMMessages(systemPrompt: String) -> [[String: Any]] {
        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        for message in conversationHistory {
            switch message.role {
            case .system:
                continue
            case .user:
                messages.append(["role": "user", "content": message.content])
            case .assistant:
                var dict: [String: Any] = ["role": "assistant"]
                if !message.content.isEmpty {
                    dict["content"] = message.content
                }
                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    dict["tool_calls"] = toolCalls.map { call in
                        [
                            "id": call.id,
                            "type": "function",
                            "function": [
                                "name": call.name,
                                "arguments": call.argumentsJSON
                            ]
                        ] as [String: Any]
                    }
                }
                messages.append(dict)
            case .tool:
                var dict: [String: Any] = [
                    "role": "tool",
                    "content": message.content
                ]
                if let toolCallID = message.toolCallID {
                    dict["tool_call_id"] = toolCallID
                }
                messages.append(dict)
            }
        }

        return messages
    }

    private func proposalToolResult(_ proposal: AgentProposal) -> String {
        encodeJSON([
            "proposal_id": proposal.id.uuidString,
            "status": "pending_confirmation",
            "kind": proposal.kind.rawValue,
            "summary": proposal.summary,
            "message": "操作已生成待确认提案，请告知用户点击确认后才会生效"
        ])
    }

    private func encodeError(_ error: Error) -> String {
        encodeJSON([
            "error": true,
            "message": error.localizedDescription
        ])
    }

    private func encodeJSON(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return "{\"error\":true}"
        }
        return string
    }

    private func resolveAPIKey() -> String? {
        if let keychainKey = keychainService.loadAPIKey() {
            let trimmed = keychainKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        if AppSecrets.isConfigured {
            return AppSecrets.dashscopeAPIKey
        }
        return nil
    }

    private func updateUITurnProposalStatus(id: UUID, status: AgentProposalStatus) {
        for index in uiTurns.indices {
            if uiTurns[index].proposal?.id == id {
                var proposal = uiTurns[index].proposal!
                proposal.status = status
                uiTurns[index] = ConversationTurn(
                    id: uiTurns[index].id,
                    role: uiTurns[index].role,
                    text: uiTurns[index].text,
                    proposal: proposal,
                    attachedImage: uiTurns[index].attachedImage,
                    isStreaming: false
                )
            }
        }
    }
}
