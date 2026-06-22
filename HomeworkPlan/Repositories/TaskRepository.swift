import Foundation
import SwiftData

@MainActor
final class TaskRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func create(
        subject: Subject?,
        content: String,
        notes: String = "",
        dueDate: Date
    ) throws -> HomeworkTask {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TaskRepositoryError.emptyContent
        }

        let task = HomeworkTask(
            subject: subject,
            content: trimmed,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate
        )
        context.insert(task)
        try context.save()
        return task
    }

    func markComplete(id: UUID) throws {
        guard let task = try fetchTask(id: id) else { return }
        task.isCompleted = true
        task.completedAt = Date()
        try context.save()
    }

    func markIncomplete(id: UUID) throws {
        guard let task = try fetchTask(id: id) else { return }
        task.isCompleted = false
        task.completedAt = nil
        try context.save()
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
    }

    func delete(id: UUID) throws {
        guard let task = try fetchTask(id: id) else { return }
        context.delete(task)
        try context.save()
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
