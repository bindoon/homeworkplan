import Foundation
import SwiftData

@MainActor
final class RecurringRuleRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func create(
        subject: Subject?,
        content: String,
        frequency: RecurringFrequency,
        weeklyWeekday: Int = 2,
        customWeekdaysMask: Int = 0,
        reminderTime: Date = Date()
    ) throws -> RecurringRule {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RecurringRuleError.emptyContent
        }
        if frequency == .custom, customWeekdaysMask == 0 {
            throw RecurringRuleError.invalidCustomWeekdays
        }

        let rule = RecurringRule(
            subject: subject,
            content: trimmed,
            frequency: frequency,
            weeklyWeekday: weeklyWeekday,
            customWeekdaysMask: customWeekdaysMask,
            reminderTime: reminderTime
        )
        context.insert(rule)
        try context.save()
        return rule
    }

    func update(
        id: UUID,
        subject: Subject?,
        content: String,
        frequency: RecurringFrequency,
        weeklyWeekday: Int,
        customWeekdaysMask: Int,
        reminderTime: Date
    ) throws {
        guard let rule = try fetch(id: id) else {
            throw RecurringRuleError.notFound
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RecurringRuleError.emptyContent
        }
        if frequency == .custom, customWeekdaysMask == 0 {
            throw RecurringRuleError.invalidCustomWeekdays
        }

        rule.subject = subject
        rule.content = trimmed
        rule.frequency = frequency
        rule.weeklyWeekday = weeklyWeekday
        rule.customWeekdaysMask = customWeekdaysMask
        rule.reminderTime = reminderTime
        try context.save()
    }

    func setEnabled(id: UUID, enabled: Bool) throws {
        guard let rule = try fetch(id: id) else {
            throw RecurringRuleError.notFound
        }
        rule.isEnabled = enabled
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let rule = try fetch(id: id) else {
            throw RecurringRuleError.notFound
        }
        context.delete(rule)
        try context.save()
    }

    func fetchAll() throws -> [RecurringRule] {
        let descriptor = FetchDescriptor<RecurringRule>(
            sortBy: [SortDescriptor(\RecurringRule.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchEnabled() throws -> [RecurringRule] {
        let descriptor = FetchDescriptor<RecurringRule>(
            predicate: #Predicate { $0.isEnabled == true },
            sortBy: [SortDescriptor(\RecurringRule.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> RecurringRule? {
        let descriptor = FetchDescriptor<RecurringRule>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
}
