import Foundation
import SwiftData

@MainActor
final class TaskRepository {
    private let context: ModelContext
    var reminderService: ReminderService?

    init(context: ModelContext) {
        self.context = context
    }

    func create(
        subject: Subject?,
        content: String,
        notes: String = "",
        dueDate: Date,
        sourceType: String = ImportSourceType.manual.rawValue,
        sourceDetail: String = "",
        sourceImagePath: String = "",
        recurringRuleId: UUID? = nil,
        generationKey: String = ""
    ) throws -> HomeworkTask {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TaskRepositoryError.emptyContent
        }

        let task = HomeworkTask(
            subject: subject,
            content: trimmed,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate,
            sourceType: sourceType,
            sourceDetail: sourceDetail.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceImagePath: sourceImagePath,
            recurringRuleId: recurringRuleId,
            generationKey: generationKey
        )
        context.insert(task)
        try context.save()
        if sourceType != ImportSourceType.recurring.rawValue {
            notifySchedule(task)
        }
        return task
    }

    func createRecurring(
        subject: Subject?,
        content: String,
        dueDate: Date,
        recurringRuleId: UUID,
        generationKey: String
    ) throws -> HomeworkTask {
        try create(
            subject: subject,
            content: content,
            dueDate: dueDate,
            sourceType: ImportSourceType.recurring.rawValue,
            recurringRuleId: recurringRuleId,
            generationKey: generationKey
        )
    }

    func fetchByGenerationKey(_ key: String) throws -> HomeworkTask? {
        guard !key.isEmpty else { return nil }
        let descriptor = FetchDescriptor<HomeworkTask>(
            predicate: #Predicate { $0.generationKey == key }
        )
        return try context.fetch(descriptor).first
    }

    func markComplete(id: UUID) throws {
        guard let task = try fetchTask(id: id) else { return }
        task.isCompleted = true
        task.completedAt = Date()
        try context.save()
        notifyCancel(taskId: id)
    }

    func markIncomplete(id: UUID) throws {
        guard let task = try fetchTask(id: id) else { return }
        task.isCompleted = false
        task.completedAt = nil
        try context.save()
        notifySchedule(task)
    }

    func update(
        id: UUID,
        subject: Subject?,
        content: String,
        notes: String,
        dueDate: Date
    ) throws {
        guard let task = try fetchTask(id: id) else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TaskRepositoryError.emptyContent
        }
        task.subject = subject
        task.content = trimmed
        task.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        task.dueDate = dueDate
        try context.save()
        notifySchedule(task)
    }

    func delete(id: UUID) throws {
        guard let task = try fetchTask(id: id) else { return }
        let taskId = task.id
        context.delete(task)
        try context.save()
        notifyCancel(taskId: taskId)
    }

    func fetchIncompleteTasks(
        dueWithinDays days: Int,
        from date: Date = Date(),
        calendar: Calendar = .current
    ) throws -> [HomeworkTask] {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: days, to: start) else {
            return []
        }

        let descriptor = FetchDescriptor<HomeworkTask>(
            predicate: #Predicate { task in
                !task.isCompleted && task.dueDate >= start && task.dueDate < end
            },
            sortBy: [SortDescriptor(\HomeworkTask.dueDate)]
        )
        return try context.fetch(descriptor)
    }

    private func notifySchedule(_ task: HomeworkTask, ruleReminderTime: Date? = nil) {
        guard let reminderService else { return }
        let resolvedRuleTime: Date?
        if task.sourceType == ImportSourceType.recurring.rawValue,
           ruleReminderTime == nil,
           let ruleId = task.recurringRuleId {
            resolvedRuleTime = try? fetchRuleReminderTime(ruleId)
        } else {
            resolvedRuleTime = ruleReminderTime
        }
        Task {
            await reminderService.schedule(for: task, ruleReminderTime: resolvedRuleTime)
        }
    }

    private func fetchRuleReminderTime(_ ruleId: UUID) throws -> Date? {
        let descriptor = FetchDescriptor<RecurringRule>(
            predicate: #Predicate { $0.id == ruleId }
        )
        return try context.fetch(descriptor).first?.reminderTime
    }

    private func notifyCancel(taskId: UUID) {
        guard let reminderService else { return }
        Task {
            await reminderService.cancel(for: taskId)
        }
    }

    func fetchTasks(dueOn date: Date, includeCompleted: Bool) throws -> [HomeworkTask] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return []
        }

        let descriptor = FetchDescriptor<HomeworkTask>(
            predicate: #Predicate { task in
                task.dueDate >= start && task.dueDate < end
            },
            sortBy: [SortDescriptor(\HomeworkTask.createdAt)]
        )
        let tasks = try context.fetch(descriptor)
        if includeCompleted {
            return tasks
        }
        return tasks.filter { !$0.isCompleted }
    }

    func fetchAllTasksGroupedByDate() throws -> [Date: [HomeworkTask]] {
        let descriptor = FetchDescriptor<HomeworkTask>(
            sortBy: [SortDescriptor(\HomeworkTask.dueDate, order: .reverse)]
        )
        let tasks = try context.fetch(descriptor)
        let calendar = Calendar.current
        var grouped: [Date: [HomeworkTask]] = [:]
        for task in tasks {
            let day = calendar.startOfDay(for: task.dueDate)
            grouped[day, default: []].append(task)
        }
        return grouped
    }

    func fetchTask(id: UUID) throws -> HomeworkTask? {
        let descriptor = FetchDescriptor<HomeworkTask>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
}

enum TaskRepositoryError: LocalizedError {
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "作业内容不能为空"
        }
    }
}
