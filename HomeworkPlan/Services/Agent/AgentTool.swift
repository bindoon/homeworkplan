import Foundation

protocol AgentTool {
    var definition: ToolDefinition { get }
    var isMutating: Bool { get }
}

struct ToolDefinition {
    let name: String
    let description: String
    let parameters: [String: Any]

    func openAISchema() -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parameters
            ]
        ]
    }
}

enum AgentToolName: String, CaseIterable {
    case importFromText = "import_from_text"
    case createTask = "create_task"
    case listTasks = "list_tasks"
    case toggleTaskComplete = "toggle_task_complete"
    case deleteTask = "delete_task"
    case listSubjects = "list_subjects"
    case createSubject = "create_subject"
    case updateSubject = "update_subject"
    case deleteSubject = "delete_subject"
    case listRecurringRules = "list_recurring_rules"
    case createRecurringRule = "create_recurring_rule"
    case updateRecurringRule = "update_recurring_rule"
    case deleteRecurringRule = "delete_recurring_rule"
    case setRecurringRuleEnabled = "set_recurring_rule_enabled"
}
