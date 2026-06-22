import Foundation

enum ImportTaskAction: String, Codable, CaseIterable {
    case create
    case update
    case skip

    var displayName: String {
        switch self {
        case .create:
            return "新增"
        case .update:
            return "更新"
        case .skip:
            return "跳过"
        }
    }

    var recommendationText: String {
        switch self {
        case .create:
            return "将新增一条作业"
        case .update:
            return "将更新已有作业"
        case .skip:
            return "与已有作业重复，建议跳过"
        }
    }
}

struct ExistingTaskContextItem: Codable, Equatable, Identifiable {
    var id: String
    var subject: String
    var content: String
    var dueDate: String
    var isCompleted: Bool
}
