import Foundation

enum ToolRegistry {
    static let allDefinitions: [ToolDefinition] = [
        importFromText,
        importFromImage,
        createTask,
        listTasks,
        toggleTaskComplete,
        deleteTask,
        listSubjects,
        createSubject,
        updateSubject,
        deleteSubject,
        listRecurringRules,
        createRecurringRule,
        updateRecurringRule,
        deleteRecurringRule,
        setRecurringRuleEnabled
    ]

    static var openAITools: [[String: Any]] {
        allDefinitions.map { $0.openAISchema() }
    }

    static func definition(named name: String) -> ToolDefinition? {
        allDefinitions.first { $0.name == name }
    }

    static func isMutating(name: String) -> Bool {
        switch AgentToolName(rawValue: name) {
        case .listTasks, .listSubjects, .listRecurringRules, .none:
            return false
        default:
            return true
        }
    }

    // MARK: - Import

    static let importFromText = ToolDefinition(
        name: AgentToolName.importFromText.rawValue,
        description: "从粘贴的文本中解析作业候选列表，需用户确认后才会写入任务",
        parameters: objectSchema(
            properties: [
                "text": stringProperty(description: "要解析的作业通知或清单文本")
            ],
            required: ["text"]
        )
    )

    static let importFromImage = ToolDefinition(
        name: AgentToolName.importFromImage.rawValue,
        description: "从截图 OCR 文本导入作业（OCR 已在本地完成，使用提供的 ocr_text，勿重复识别）",
        parameters: objectSchema(
            properties: [
                "ocr_text": stringProperty(description: "本地 Vision OCR 已提取的截图文字")
            ],
            required: ["ocr_text"]
        )
    )

    // MARK: - Tasks

    static let createTask = ToolDefinition(
        name: AgentToolName.createTask.rawValue,
        description: "创建一条新作业，需用户确认后才会保存",
        parameters: objectSchema(
            properties: [
                "content": stringProperty(description: "作业内容"),
                "subject_name": stringProperty(description: "科目名称，如语文、数学"),
                "notes": stringProperty(description: "备注，可选"),
                "due_date": stringProperty(description: "截止日期，ISO8601 日期如 2026-06-25，或相对描述如明天")
            ],
            required: ["content"]
        )
    )

    static let listTasks = ToolDefinition(
        name: AgentToolName.listTasks.rawValue,
        description: "列出作业任务，可按日期范围筛选",
        parameters: objectSchema(
            properties: [
                "days_ahead": integerProperty(description: "从今天起未来多少天，默认 7"),
                "include_completed": booleanProperty(description: "是否包含已完成，默认 false")
            ],
            required: []
        )
    )

    static let toggleTaskComplete = ToolDefinition(
        name: AgentToolName.toggleTaskComplete.rawValue,
        description: "标记作业完成或未完成，需用户确认",
        parameters: objectSchema(
            properties: [
                "task_id": stringProperty(description: "任务 UUID"),
                "completed": booleanProperty(description: "true 表示标记完成，false 表示标记未完成")
            ],
            required: ["task_id", "completed"]
        )
    )

    static let deleteTask = ToolDefinition(
        name: AgentToolName.deleteTask.rawValue,
        description: "删除一条作业，需用户确认",
        parameters: objectSchema(
            properties: [
                "task_id": stringProperty(description: "任务 UUID")
            ],
            required: ["task_id"]
        )
    )

    // MARK: - Subjects

    static let listSubjects = ToolDefinition(
        name: AgentToolName.listSubjects.rawValue,
        description: "列出所有科目",
        parameters: objectSchema(properties: [:], required: [])
    )

    static let createSubject = ToolDefinition(
        name: AgentToolName.createSubject.rawValue,
        description: "创建新科目，需用户确认",
        parameters: objectSchema(
            properties: [
                "name": stringProperty(description: "科目名称"),
                "emoji": stringProperty(description: "科目 emoji，默认 📚")
            ],
            required: ["name"]
        )
    )

    static let updateSubject = ToolDefinition(
        name: AgentToolName.updateSubject.rawValue,
        description: "更新科目名称或 emoji，需用户确认",
        parameters: objectSchema(
            properties: [
                "subject_id": stringProperty(description: "科目 UUID"),
                "name": stringProperty(description: "新名称"),
                "emoji": stringProperty(description: "新 emoji")
            ],
            required: ["subject_id"]
        )
    )

    static let deleteSubject = ToolDefinition(
        name: AgentToolName.deleteSubject.rawValue,
        description: "删除科目（默认科目不可删），需用户确认",
        parameters: objectSchema(
            properties: [
                "subject_id": stringProperty(description: "科目 UUID")
            ],
            required: ["subject_id"]
        )
    )

    // MARK: - Recurring

    static let listRecurringRules = ToolDefinition(
        name: AgentToolName.listRecurringRules.rawValue,
        description: "列出所有重复作业规则",
        parameters: objectSchema(properties: [:], required: [])
    )

    static let createRecurringRule = ToolDefinition(
        name: AgentToolName.createRecurringRule.rawValue,
        description: "创建重复作业规则，需用户确认",
        parameters: objectSchema(
            properties: [
                "content": stringProperty(description: "作业内容"),
                "subject_name": stringProperty(description: "科目名称"),
                "frequency": enumProperty(
                    description: "重复频率",
                    values: ["daily", "weekdays", "weekly", "custom"]
                ),
                "weekly_weekday": integerProperty(description: "weekly 时使用的 weekday，1=周日…7=周六，默认 2（周一）"),
                "custom_weekdays_mask": integerProperty(description: "custom 时的 weekday 位掩码"),
                "reminder_time": stringProperty(description: "提醒时间 HH:mm，默认 18:00")
            ],
            required: ["content", "frequency"]
        )
    )

    static let updateRecurringRule = ToolDefinition(
        name: AgentToolName.updateRecurringRule.rawValue,
        description: "更新重复作业规则，需用户确认",
        parameters: objectSchema(
            properties: [
                "rule_id": stringProperty(description: "规则 UUID"),
                "content": stringProperty(description: "作业内容"),
                "subject_name": stringProperty(description: "科目名称"),
                "frequency": enumProperty(
                    description: "重复频率",
                    values: ["daily", "weekdays", "weekly", "custom"]
                ),
                "weekly_weekday": integerProperty(description: "weekly weekday"),
                "custom_weekdays_mask": integerProperty(description: "custom 位掩码"),
                "reminder_time": stringProperty(description: "提醒时间 HH:mm")
            ],
            required: ["rule_id"]
        )
    )

    static let deleteRecurringRule = ToolDefinition(
        name: AgentToolName.deleteRecurringRule.rawValue,
        description: "删除重复作业规则，需用户确认",
        parameters: objectSchema(
            properties: [
                "rule_id": stringProperty(description: "规则 UUID")
            ],
            required: ["rule_id"]
        )
    )

    static let setRecurringRuleEnabled = ToolDefinition(
        name: AgentToolName.setRecurringRuleEnabled.rawValue,
        description: "启用或停用重复作业规则，需用户确认",
        parameters: objectSchema(
            properties: [
                "rule_id": stringProperty(description: "规则 UUID"),
                "enabled": booleanProperty(description: "true 启用，false 停用")
            ],
            required: ["rule_id", "enabled"]
        )
    )

    // MARK: - Schema helpers

    private static func objectSchema(properties: [String: Any], required: [String]) -> [String: Any] {
        var schema: [String: Any] = [
            "type": "object",
            "properties": properties
        ]
        if !required.isEmpty {
            schema["required"] = required
        }
        return schema
    }

    private static func stringProperty(description: String) -> [String: Any] {
        ["type": "string", "description": description]
    }

    private static func integerProperty(description: String) -> [String: Any] {
        ["type": "integer", "description": description]
    }

    private static func booleanProperty(description: String) -> [String: Any] {
        ["type": "boolean", "description": description]
    }

    private static func enumProperty(description: String, values: [String]) -> [String: Any] {
        ["type": "string", "description": description, "enum": values]
    }
}
