import Foundation
import Observation

@Observable
@MainActor
final class ActionConsoleViewModel {
    var inputText: String = ""
    var turns: [ConversationTurn] = []
    var isProcessing: Bool = false
    var errorMessage: String?

    private let orchestrator: AgentOrchestrator

    init(orchestrator: AgentOrchestrator) {
        self.orchestrator = orchestrator
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isProcessing else { return }

        inputText = ""
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            _ = try await orchestrator.sendUserMessage(text)
            syncTurns()
        } catch {
            errorMessage = error.localizedDescription
            syncTurns()
        }
    }

    func confirmProposal(id: UUID) {
        do {
            _ = try orchestrator.confirmProposal(id: id)
            errorMessage = nil
            syncTurns()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectProposal(id: UUID) {
        orchestrator.rejectProposal(id: id)
        syncTurns()
    }

    func clearConversation() {
        orchestrator.clearConversation()
        turns = []
        errorMessage = nil
    }

    private func syncTurns() {
        turns = orchestrator.uiTurns
    }
}
