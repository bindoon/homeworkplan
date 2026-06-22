import Foundation

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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AgentTurn(messages: conversationHistory)
        }

        let userMessage = AgentMessage(role: .user, content: trimmed)
        conversationHistory.append(userMessage)
        uiTurns.append(ConversationTurn(role: .user, text: trimmed))

        var turnProposals: [AgentProposal] = []
        var rounds = 0

        while rounds < Self.maxToolRounds {
            rounds += 1

            guard let apiKey = resolveAPIKey() else {
                throw AgentOrchestratorError.missingAPIKey
            }

            let subjects = (try? subjectRepository.fetchAll()) ?? []
            let llmMessages = buildLLMMessages(systemPrompt: AgentSystemPrompt.build(subjects: subjects))
            let response = try await llmService.chat(
                messages: llmMessages,
                tools: ToolRegistry.openAITools,
                apiKey: apiKey
            )

            if response.toolCalls.isEmpty {
                let reply = response.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "好的。"
                let assistantMessage = AgentMessage(role: .assistant, content: reply)
                conversationHistory.append(assistantMessage)
                uiTurns.append(ConversationTurn(role: .assistant, text: reply))
                return AgentTurn(messages: conversationHistory, proposals: turnProposals)
            }

            let assistantMessage = AgentMessage(
                role: .assistant,
                content: response.content ?? "",
                toolCalls: response.toolCalls
            )
            conversationHistory.append(assistantMessage)

            for toolCall in response.toolCalls {
                let toolResult: String
                do {
                    let execution = try await toolExecutor.execute(
                        toolName: toolCall.name,
                        argumentsJSON: toolCall.argumentsJSON
                    )
                    switch execution {
                    case .immediate(let json):
                        toolResult = json
                    case .proposal(var proposal):
                        pendingProposals.append(proposal)
                        turnProposals.append(proposal)
                        uiTurns.append(ConversationTurn(role: .assistant, text: proposal.summary, proposal: proposal))
                        toolResult = proposalToolResult(proposal)
                    }
                } catch {
                    toolResult = encodeError(error)
                }

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

    // MARK: - Private

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
                    proposal: proposal
                )
            }
        }
    }
}
