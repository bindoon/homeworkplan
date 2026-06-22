import Foundation

enum ToolExecutorError: LocalizedError {
    case unknownTool(String)
    case invalidArguments(String)
    case notFound(String)
    case serviceError(String)

    var errorDescription: String? {
        switch self {
        case .unknownTool(let name):
            return "未知工具：\(name)"
        case .invalidArguments(let detail):
            return "参数无效：\(detail)"
        case .notFound(let detail):
            return "未找到：\(detail)"
        case .serviceError(let detail):
            return detail
        }
    }
}

@MainActor
final class ToolExecutor {
    private let taskRepository: TaskRepository
    private let subjectRepository: SubjectRepository
    private let recurringRuleRepository: RecurringRuleRepository
    private let importService: ImportService

    init(
        taskRepository: TaskRepository,
        subjectRepository: SubjectRepository,
        recurringRuleRepository: RecurringRuleRepository,
        importService: ImportService
    ) {
        self.taskRepository = taskRepository
        self.subjectRepository = subjectRepository
        self.recurringRuleRepository = recurringRuleRepository
        self.importService = importService
    }

    func execute(toolName: String, argumentsJSON: String) async throws -> ToolExecutionResult {
        guard let tool = AgentToolName(rawValue: toolName) else {
            throw ToolExecutorError.unknownTool(toolName)
        }

        let args = try parseArguments(argumentsJSON)

        switch tool {
        case .importFromText:
            return try await executeImportFromText(args)
        case .createTask:
            return try executeCreateTask(args)
        case .listTasks:
            return try executeListTasks(args)
        case .toggleTaskComplete:
            return try executeToggleTaskComplete(args)
        case .deleteTask:
            return try executeDeleteTask(args)
        case .listSubjects:
            return try executeListSubjects()
        case .createSubject:
            return try executeCreateSubject(args)
        case .updateSubject:
            return try executeUpdateSubject(args)
        case .deleteSubject:
            return try executeDeleteSubject(args)
        case .listRecurringRules:
            return try executeListRecurringRules()
        case .createRecurringRule:
            return try executeCreateRecurringRule(args)
        case .updateRecurringRule:
            return try executeUpdateRecurringRule(args)
        case .deleteRecurringRule:
            return try executeDeleteRecurringRule(args)
        case .setRecurringRuleEnabled:
            return try executeSetRecurringRuleEnabled(args)
        }
    }

    func confirmProposal(_ proposal: AgentProposal) throws -> String {
        guard proposal.status == .pending else {
            throw AgentOrchestratorError.proposalAlreadyHandled
        }

        switch proposal.payload {
        case .createTask(let payload):
            let subject = try resolveSubject(id: payload.subjectID, name: payload.subjectName)
            let task = try taskRepository.create(
                subject: subject,
                content: payload.content,
                notes: payload.notes,
                dueDate: payload.dueDate
            )
            return "已创建作业：\(task.content)"

        case .importCandidates(let payload):
            let subjects = try subjectRepository.fetchAll()
            var created = 0
            for candidate in payload.candidates where candidate.action != .skip {
                let subject = subjects.first {
                    Subject.normalizeName($0.name) == Subject.normalizeName(candidate.subjectName)
                }
                let dueDate = DueDateResolver.resolve(
                    for: candidate,
                    importedAt: Date(),
                    rawText: payload.rawText
                )
                switch candidate.action {
                case .create:
                    _ = try taskRepository.create(
                        subject: subject,
                        content: candidate.content,
                        notes: candidate.notes ?? "",
                        dueDate: dueDate,
                        sourceType: payload.sourceType.rawValue
                    )
                    created += 1
                case .update:
                    if let taskID = candidate.matchedTaskId {
                        try taskRepository.update(
                            id: taskID,
                            subject: subject,
                            content: candidate.content,
                            notes: candidate.notes ?? "",
                            dueDate: dueDate
                        )
                        created += 1
                    }
                case .skip:
                    break
                }
            }
            return "已导入 \(created) 条作业"

        case .createSubject(let payload):
            let subject = try subjectRepository.create(name: payload.name, emoji: payload.emoji)
            return "已创建科目：\(subject.emoji) \(subject.name)"

        case .updateSubject(let payload):
            try subjectRepository.update(id: payload.subjectID, name: payload.name, emoji: payload.emoji)
            return "已更新科目：\(payload.emoji) \(payload.name)"

        case .deleteSubject(let payload):
            try subjectRepository.delete(id: payload.subjectID)
            return "已删除科目：\(payload.subjectName)"

        case .createRecurringRule(let payload):
            let subject = try resolveSubject(id: payload.subjectID, name: payload.subjectName)
            let rule = try recurringRuleRepository.create(
                subject: subject,
                content: payload.content,
                frequency: payload.frequency,
                weeklyWeekday: payload.weeklyWeekday,
                customWeekdaysMask: payload.customWeekdaysMask,
                reminderTime: payload.reminderTime
            )
            return "已创建重复规则：\(rule.content)"

        case .updateRecurringRule(let payload):
            let subject = try resolveSubject(id: payload.subjectID, name: "")
            try recurringRuleRepository.update(
                id: payload.ruleID,
                subject: subject,
                content: payload.content,
                frequency: payload.frequency,
                weeklyWeekday: payload.weeklyWeekday,
                customWeekdaysMask: payload.customWeekdaysMask,
                reminderTime: payload.reminderTime
            )
            return "已更新重复规则"

        case .deleteRecurringRule(let payload):
            try recurringRuleRepository.delete(id: payload.ruleID)
            return "已删除重复规则：\(payload.content)"

        case .toggleTaskComplete(let payload):
            if payload.markComplete {
                try taskRepository.markComplete(id: payload.taskID)
                return "已标记完成：\(payload.content)"
            } else {
                try taskRepository.markIncomplete(id: payload.taskID)
                return "已标记未完成：\(payload.content)"
            }

        case .deleteTask(let payload):
            try taskRepository.delete(id: payload.taskID)
            return "已删除作业：\(payload.content)"

        case .setRecurringRuleEnabled(let payload):
            try recurringRuleRepository.setEnabled(id: payload.ruleID, enabled: payload.enabled)
            return payload.enabled ? "已启用重复规则：\(payload.content)" : "已停用重复规则：\(payload.content)"
        }
    }

    // MARK: - Tool implementations

    private func executeImportFromText(_ args: [String: Any]) async throws -> ToolExecutionResult {
        guard let text = args["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ToolExecutorError.invalidArguments("text 不能为空")
        }

        do {
            let result = try await importService.processPastedText(text)
            let createCount = result.candidates.filter { $0.action == .create || $0.action == .update }.count
            let lines = result.candidates.prefix(5).map { candidate in
                let dateStr = candidate.dueDate.map { formatDate($0) } ?? "未指定"
                return "• [\(candidate.subjectName)] \(candidate.content)（\(dateStr)）"
            }
            var detailLines = Array(lines)
            if result.candidates.count > 5 {
                detailLines.append("… 共 \(result.candidates.count) 条")
            }
            if result.isDuplicate {
                detailLines.insert("⚠️ 该内容曾导入过", at: 0)
            }
            if result.parseFailed {
                throw ToolExecutorError.serviceError(result.message ?? "解析失败")
            }

            let proposal = AgentProposal(
                kind: .importCandidates,
                summary: "导入 \(createCount) 条作业候选",
                detailLines: detailLines,
                payload: .importCandidates(
                    ImportCandidatesPayload(
                        candidates: result.candidates,
                        rawText: result.rawText,
                        importRecordID: result.importRecord?.id,
                        sourceType: result.sourceType
                    )
                )
            )
            return .proposal(proposal)
        } catch let error as ImportServiceError {
            throw ToolExecutorError.serviceError(error.localizedDescription)
        }
    }

    private func executeCreateTask(_ args: [String: Any]) throws -> ToolExecutionResult {
        guard let content = args["content"] as? String,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ToolExecutorError.invalidArguments("content 不能为空")
        }

        let subjectName = (args["subject_name"] as? String) ?? "其他"
        let notes = (args["notes"] as? String) ?? ""
        let dueDateStr = args["due_date"] as? String
        let dueDate = resolveDueDate(from: dueDateStr, content: content)

        let subjects = try subjectRepository.fetchAll()
        let subject = subjects.first {
            Subject.normalizeName($0.name) == Subject.normalizeName(subjectName)
        }

        let proposal = AgentProposal(
            kind: .createTask,
            summary: "创建作业",
            detailLines: [
                "科目：\(subject?.name ?? subjectName)",
                "内容：\(content.trimmingCharacters(in: .whitespacesAndNewlines))",
                "截止：\(formatDate(dueDate))"
            ],
            payload: .createTask(
                CreateTaskPayload(
                    subjectID: subject?.id,
                    subjectName: subjectName,
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: notes,
                    dueDate: dueDate
                )
            )
        )
        return .proposal(proposal)
    }

    private func executeListTasks(_ args: [String: Any]) throws -> ToolExecutionResult {
        let daysAhead = args["days_ahead"] as? Int ?? 7
        let includeCompleted = args["include_completed"] as? Bool ?? false
        let tasks = try taskRepository.fetchIncompleteTasks(dueWithinDays: daysAhead)
        let filtered = includeCompleted ? try fetchAllRecentTasks(daysAhead: daysAhead) : tasks

        let payload: [[String: Any]] = filtered.map { task in
            [
                "id": task.id.uuidString,
                "content": task.content,
                "subject": task.subject?.name ?? "其他",
                "due_date": formatDate(task.dueDate),
                "completed": task.isCompleted
            ]
        }
        return .immediate(encodeJSON(["tasks": payload, "count": payload.count]))
    }

    private func executeToggleTaskComplete(_ args: [String: Any]) throws -> ToolExecutionResult {
        guard let taskID = parseUUID(args["task_id"]) else {
            throw ToolExecutorError.invalidArguments("task_id 无效")
        }
        guard let completed = args["completed"] as? Bool else {
            throw ToolExecutorError.invalidArguments("completed 必填")
        }
        guard let task = try taskRepository.fetchTask(id: taskID) else {
            throw ToolExecutorError.notFound("任务不存在")
        }

        let proposal = AgentProposal(
            kind: .toggleTaskComplete,
            summary: completed ? "标记完成" : "标记未完成",
            detailLines: [task.content],
            payload: .toggleTaskComplete(
                ToggleTaskCompletePayload(taskID: taskID, content: task.content, markComplete: completed)
            )
        )
        return .proposal(proposal)
    }

    private func executeDeleteTask(_ args: [String: Any]) throws -> ToolExecutionResult {
        guard let taskID = parseUUID(args["task_id"]) else {
            throw ToolExecutorError.invalidArguments("task_id 无效")
        }
        guard let task = try taskRepository.fetchTask(id: taskID) else {
            throw ToolExecutorError.notFound("任务不存在")
        }

        let proposal = AgentProposal(
            kind: .deleteTask,
            summary: "删除作业",
            detailLines: [task.content],
            payload: .deleteTask(DeleteTaskPayload(taskID: taskID, content: task.content))
        )
        return .proposal(proposal)
    }

    private func executeListSubjects() throws -> ToolExecutionResult {
        let subjects = try subjectRepository.fetchAll()
        let payload: [[String: Any]] = subjects.map {
            ["id": $0.id.uuidString, "name": $0.name, "emoji": $0.emoji, "is_default": $0.isDefault]
        }
        return .immediate(encodeJSON(["subjects": payload]))
    }

    private func executeCreateSubject(_ args: [String: Any]) throws -> ToolExecutionResult {
        guard let name = args["name"] as? String,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ToolExecutorError.invalidArguments("name 不能为空")
        }
        let emoji = (args["emoji"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "📚"
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        let proposal = AgentProposal(
            kind: .createSubject,
            summary: "创建科目",
            detailLines: ["\(emoji) \(trimmed)"],
            payload: .createSubject(CreateSubjectPayload(name: trimmed, emoji: emoji))
        )
        return .proposal(proposal)
    }

    private func executeUpdateSubject(_ args: [String: Any]) throws -> ToolExecutionResult {
        guard let subjectID = parseUUID(args["subject_id"]) else {
            throw ToolExecutorError.invalidArguments("subject_id 无效")
        }
        guard let subject = try subjectRepository.fetch(id: subjectID) else {
            throw ToolExecutorError.notFound("科目不存在")
        }
        let name = (args["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? subject.name
        let emoji = (args["emoji"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? subject.emoji

        let proposal = AgentProposal(
            kind: .updateSubject,
            summary: "更新科目",
            detailLines: ["\(emoji) \(name)"],
            payload: .updateSubject(UpdateSubjectPayload(subjectID: subjectID, name: name, emoji: emoji))
        )
        return .proposal(proposal)
    }

    private func executeDeleteSubject(_ args: [String: Any]) throws -> ToolExecutionResult {
        guard let subjectID = parseUUID(args["subject_id"]) else {
            throw ToolExecutorError.invalidArguments("subject_id 无效")
        }
        guard let subject = try subjectRepository.fetch(id: subjectID) else {
            throw ToolExecutorError.notFound("科目不存在")
        }

        let proposal = AgentProposal(
            kind: .deleteSubject,
            summary: "删除科目",
            detailLines: ["\(subject.emoji) \(subject.name)"],
            payload: .deleteSubject(DeleteSubjectPayload(subjectID: subjectID, subjectName: subject.name))
        )
        return .proposal(proposal)
    }

    private func executeListRecurringRules() throws -> ToolExecutionResult {
        let rules = try recurringRuleRepository.fetchAll()
        let payload: [[String: Any]] = rules.map { rule in
            [
                "id": rule.id.uuidString,
                "content": rule.content,
                "subject": rule.subject?.name ?? "其他",
                "frequency": rule.frequency.rawValue,
                "enabled": rule.isEnabled
            ]
        }
        return .immediate(encodeJSON(["rules": payload]))
    }

    private func executeCreateRecurringRule(_ args: [String: Any]) throws -> ToolExecutionResult {
        guard let content = args["content"] as? String,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ToolExecutorError.invalidArguments("content 不能为空")
        }
        guard let frequencyRaw = args["frequency"] as? String,
              let frequency = RecurringFrequency(rawValue: frequencyRaw) else {
            throw ToolExecutorError.invalidArguments("frequency 无效")
        }

        let subjectName = (args["subject_name"] as? String) ?? "其他"
        let weeklyWeekday = args["weekly_weekday"] as? Int ?? 2
        let customMask = args["custom_weekdays_mask"] as? Int ?? 0
        let reminderTime = parseReminderTime(args["reminder_time"] as? String)

        let subjects = try subjectRepository.fetchAll()
        let subject = subjects.first {
            Subject.normalizeName($0.name) == Subject.normalizeName(subjectName)
        }

        let freqSummary = RecurringRule.frequencySummary(
            frequency: frequency,
            weeklyWeekday: weeklyWeekday,
            customWeekdaysMask: customMask
        )

        let proposal = AgentProposal(
            kind: .createRecurringRule,
            summary: "创建重复作业",
            detailLines: [
                "内容：\(content.trimmingCharacters(in: .whitespacesAndNewlines))",
                "科目：\(subject?.name ?? subjectName)",
                "频率：\(freqSummary)"
            ],
            payload: .createRecurringRule(
                CreateRecurringRulePayload(
                    subjectID: subject?.id,
                    subjectName: subjectName,
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    frequency: frequency,
                    weeklyWeekday: weeklyWeekday,
                    customWeekdaysMask: customMask,
                    reminderTime: reminderTime
                )
            )
        )
        return .proposal(proposal)
    }

    private func executeUpdateRecurringRule(_ args: [String: Any]) throws -> ToolExecutionResult {
        guard let ruleID = parseUUID(args["rule_id"]) else {
            throw ToolExecutorError.invalidArguments("rule_id 无效")
        }
        guard let rule = try recurringRuleRepository.fetch(id: ruleID) else {
            throw ToolExecutorError.notFound("规则不存在")
        }

        let content = (args["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? rule.content
        let frequencyRaw = args["frequency"] as? String
        let frequency = frequencyRaw.flatMap { RecurringFrequency(rawValue: $0) } ?? rule.frequency
        let weeklyWeekday = args["weekly_weekday"] as? Int ?? rule.weeklyWeekday
        let customMask = args["custom_weekdays_mask"] as? Int ?? rule.customWeekdaysMask
        let reminderTime = args["reminder_time"] != nil
            ? parseReminderTime(args["reminder_time"] as? String)
            : rule.reminderTime

        var subjectID = rule.subject?.id
        if let subjectName = args["subject_name"] as? String {
            let subjects = try subjectRepository.fetchAll()
            subjectID = subjects.first {
                Subject.normalizeName($0.name) == Subject.normalizeName(subjectName)
            }?.id
        }

        let proposal = AgentProposal(
            kind: .updateRecurringRule,
            summary: "更新重复作业规则",
            detailLines: [content],
            payload: .updateRecurringRule(
                UpdateRecurringRulePayload(
                    ruleID: ruleID,
                    subjectID: subjectID,
                    content: content,
                    frequency: frequency,
                    weeklyWeekday: weeklyWeekday,
                    customWeekdaysMask: customMask,
                    reminderTime: reminderTime
                )
            )
        )
        return .proposal(proposal)
    }

    private func executeDeleteRecurringRule(_ args: [String: Any]) throws -> ToolExecutionResult {
        guard let ruleID = parseUUID(args["rule_id"]) else {
            throw ToolExecutorError.invalidArguments("rule_id 无效")
        }
        guard let rule = try recurringRuleRepository.fetch(id: ruleID) else {
            throw ToolExecutorError.notFound("规则不存在")
        }

        let proposal = AgentProposal(
            kind: .deleteRecurringRule,
            summary: "删除重复作业规则",
            detailLines: [rule.content],
            payload: .deleteRecurringRule(DeleteRecurringRulePayload(ruleID: ruleID, content: rule.content))
        )
        return .proposal(proposal)
    }

    private func executeSetRecurringRuleEnabled(_ args: [String: Any]) throws -> ToolExecutionResult {
        guard let ruleID = parseUUID(args["rule_id"]) else {
            throw ToolExecutorError.invalidArguments("rule_id 无效")
        }
        guard let enabled = args["enabled"] as? Bool else {
            throw ToolExecutorError.invalidArguments("enabled 必填")
        }
        guard let rule = try recurringRuleRepository.fetch(id: ruleID) else {
            throw ToolExecutorError.notFound("规则不存在")
        }

        let proposal = AgentProposal(
            kind: .setRecurringRuleEnabled,
            summary: enabled ? "启用重复规则" : "停用重复规则",
            detailLines: [rule.content],
            payload: .setRecurringRuleEnabled(
                SetRecurringRuleEnabledPayload(ruleID: ruleID, content: rule.content, enabled: enabled)
            )
        )
        return .proposal(proposal)
    }

    // MARK: - Helpers

    private func parseArguments(_ json: String) throws -> [String: Any] {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            return [:]
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ToolExecutorError.invalidArguments("无法解析 JSON")
        }
        return object
    }

    private func parseUUID(_ value: Any?) -> UUID? {
        guard let raw = value as? String else { return nil }
        return UUID(uuidString: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func resolveSubject(id: UUID?, name: String) throws -> Subject? {
        if let id, let subject = try subjectRepository.fetch(id: id) {
            return subject
        }
        let subjects = try subjectRepository.fetchAll()
        return subjects.first {
            Subject.normalizeName($0.name) == Subject.normalizeName(name)
        }
    }

    private func resolveDueDate(from dueDateStr: String?, content: String) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let dueDateStr, !dueDateStr.isEmpty {
            if let parsed = TaskCandidate.parseLocalDateString(dueDateStr) {
                return calendar.startOfDay(for: parsed)
            }
            let candidate = TaskCandidate(subjectName: "其他", content: content, dueDate: nil)
            let combined = "\(dueDateStr) \(content)"
            return DueDateResolver.resolve(for: candidate, importedAt: Date(), rawText: combined)
        }

        let candidate = TaskCandidate(subjectName: "其他", content: content)
        return DueDateResolver.resolve(for: candidate, importedAt: Date(), rawText: content)
    }

    private func parseReminderTime(_ value: String?) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let value, !value.isEmpty else {
            return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: today) ?? today
        }
        let parts = value.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: today) ?? today
        }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
    }

    private func fetchAllRecentTasks(daysAhead: Int) throws -> [HomeworkTask] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: daysAhead, to: start) else {
            return []
        }
        let incomplete = try taskRepository.fetchIncompleteTasks(dueWithinDays: daysAhead)
        // Include completed within range via fetchTasks per day - simplified: return incomplete only for now
        // When include_completed true, extend with completed tasks
        var result = incomplete
        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let dayTasks = try taskRepository.fetchTasks(dueOn: day, includeCompleted: true)
            for task in dayTasks where task.isCompleted {
                if !result.contains(where: { $0.id == task.id }) {
                    result.append(task)
                }
            }
        }
        return result.sorted { $0.dueDate < $1.dueDate }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func encodeJSON(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
