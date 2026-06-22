import Foundation
import UIKit

struct UserMessageAttachment {
    let image: UIImage
    let ocrText: String
}

enum AgentMessageRole: String, Codable {
    case system
    case user
    case assistant
    case tool
}

struct AgentMessage: Identifiable, Equatable {
    let id: UUID
    let role: AgentMessageRole
    let content: String
    let toolCallID: String?
    let toolCalls: [AgentToolCall]?

    init(
        id: UUID = UUID(),
        role: AgentMessageRole,
        content: String,
        toolCallID: String? = nil,
        toolCalls: [AgentToolCall]? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.toolCallID = toolCallID
        self.toolCalls = toolCalls
    }
}

struct AgentToolCall: Equatable {
    let id: String
    let name: String
    let argumentsJSON: String
}

struct AgentTurn: Identifiable {
    let id: UUID
    var messages: [AgentMessage]
    var proposals: [AgentProposal]
    var isProcessing: Bool
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        messages: [AgentMessage] = [],
        proposals: [AgentProposal] = [],
        isProcessing: Bool = false,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.messages = messages
        self.proposals = proposals
        self.isProcessing = isProcessing
        self.errorMessage = errorMessage
    }
}

enum AgentProposalKind: String, Codable {
    case createTask
    case importCandidates
    case createSubject
    case updateSubject
    case deleteSubject
    case createRecurringRule
    case updateRecurringRule
    case deleteRecurringRule
    case toggleTaskComplete
    case deleteTask
    case setRecurringRuleEnabled
}

struct AgentProposal: Identifiable, Equatable {
    let id: UUID
    let kind: AgentProposalKind
    let summary: String
    let detailLines: [String]
    let payload: AgentProposalPayload
    var status: AgentProposalStatus

    init(
        id: UUID = UUID(),
        kind: AgentProposalKind,
        summary: String,
        detailLines: [String] = [],
        payload: AgentProposalPayload,
        status: AgentProposalStatus = .pending
    ) {
        self.id = id
        self.kind = kind
        self.summary = summary
        self.detailLines = detailLines
        self.payload = payload
        self.status = status
    }
}

enum AgentProposalStatus: String, Codable {
    case pending
    case confirmed
    case rejected
}

enum AgentProposalPayload: Equatable {
    case createTask(CreateTaskPayload)
    case importCandidates(ImportCandidatesPayload)
    case createSubject(CreateSubjectPayload)
    case updateSubject(UpdateSubjectPayload)
    case deleteSubject(DeleteSubjectPayload)
    case createRecurringRule(CreateRecurringRulePayload)
    case updateRecurringRule(UpdateRecurringRulePayload)
    case deleteRecurringRule(DeleteRecurringRulePayload)
    case toggleTaskComplete(ToggleTaskCompletePayload)
    case deleteTask(DeleteTaskPayload)
    case setRecurringRuleEnabled(SetRecurringRuleEnabledPayload)
}

struct CreateTaskPayload: Equatable {
    var subjectID: UUID?
    var subjectName: String
    var content: String
    var notes: String
    var dueDate: Date
}

struct ImportCandidatesPayload: Equatable {
    var candidates: [TaskCandidate]
    var rawText: String
    var importRecordID: UUID?
    var sourceType: ImportSourceType
}

struct CreateSubjectPayload: Equatable {
    var name: String
    var emoji: String
}

struct UpdateSubjectPayload: Equatable {
    var subjectID: UUID
    var name: String
    var emoji: String
}

struct DeleteSubjectPayload: Equatable {
    var subjectID: UUID
    var subjectName: String
}

struct CreateRecurringRulePayload: Equatable {
    var subjectID: UUID?
    var subjectName: String
    var content: String
    var frequency: RecurringFrequency
    var weeklyWeekday: Int
    var customWeekdaysMask: Int
    var reminderTime: Date
}

struct UpdateRecurringRulePayload: Equatable {
    var ruleID: UUID
    var subjectID: UUID?
    var content: String
    var frequency: RecurringFrequency
    var weeklyWeekday: Int
    var customWeekdaysMask: Int
    var reminderTime: Date
}

struct DeleteRecurringRulePayload: Equatable {
    var ruleID: UUID
    var content: String
}

struct ToggleTaskCompletePayload: Equatable {
    var taskID: UUID
    var content: String
    var markComplete: Bool
}

struct DeleteTaskPayload: Equatable {
    var taskID: UUID
    var content: String
}

struct SetRecurringRuleEnabledPayload: Equatable {
    var ruleID: UUID
    var content: String
    var enabled: Bool
}

struct ConversationTurn: Identifiable {
    let id: UUID
    let role: AgentMessageRole
    let text: String
    let proposal: AgentProposal?
    let attachedImage: UIImage?

    init(
        id: UUID = UUID(),
        role: AgentMessageRole,
        text: String,
        proposal: AgentProposal? = nil,
        attachedImage: UIImage? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.proposal = proposal
        self.attachedImage = attachedImage
    }
}

enum ToolExecutionResult {
    case immediate(String)
    case proposal(AgentProposal)
}

enum AgentOrchestratorError: LocalizedError {
    case missingAPIKey
    case proposalNotFound
    case proposalAlreadyHandled
    case maxToolRoundsExceeded

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "AI 服务未配置，请在设置中填写 API Key"
        case .proposalNotFound:
            return "找不到待确认的操作"
        case .proposalAlreadyHandled:
            return "该操作已处理"
        case .maxToolRoundsExceeded:
            return "操作步骤过多，请简化请求后重试"
        }
    }
}
