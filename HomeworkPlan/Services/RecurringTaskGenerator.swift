import Foundation
import SwiftData

@MainActor
final class RecurringTaskGenerator {
    private let context: ModelContext
    private let taskRepository: TaskRepository
    private let ruleRepository: RecurringRuleRepository
    private let reminderService: ReminderService?

    init(
        context: ModelContext,
        taskRepository: TaskRepository,
        ruleRepository: RecurringRuleRepository,
        reminderService: ReminderService? = nil
    ) {
        self.context = context
        self.taskRepository = taskRepository
        self.ruleRepository = ruleRepository
        self.reminderService = reminderService
    }

    func generateIfNeeded(for date: Date = Date(), calendar: Calendar = .current) throws {
        let dayStart = calendar.startOfDay(for: date)
        let rules = try ruleRepository.fetchEnabled()

        for rule in rules {
            guard rule.shouldGenerate(on: dayStart, calendar: calendar) else { continue }

            let generationKey = HomeworkTask.makeGenerationKey(
                ruleId: rule.id,
                date: dayStart,
                calendar: calendar
            )

            if try taskRepository.fetchByGenerationKey(generationKey) != nil {
                continue
            }

            let task = try taskRepository.createRecurring(
                subject: rule.subject,
                content: rule.content,
                dueDate: dayStart,
                recurringRuleId: rule.id,
                generationKey: generationKey
            )

            if let reminderService {
                Task {
                    await reminderService.schedule(for: task, ruleReminderTime: rule.reminderTime)
                }
            }

            rule.lastGeneratedDate = dayStart
        }

        try context.save()
    }
}
