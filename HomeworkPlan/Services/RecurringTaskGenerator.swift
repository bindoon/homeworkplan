import Foundation
import SwiftData

@MainActor
final class RecurringTaskGenerator {
    private let context: ModelContext
    private let taskRepository: TaskRepository
    private let ruleRepository: RecurringRuleRepository

    init(
        context: ModelContext,
        taskRepository: TaskRepository,
        ruleRepository: RecurringRuleRepository
    ) {
        self.context = context
        self.taskRepository = taskRepository
        self.ruleRepository = ruleRepository
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

            _ = try taskRepository.createRecurring(
                subject: rule.subject,
                content: rule.content,
                dueDate: dayStart,
                recurringRuleId: rule.id,
                generationKey: generationKey
            )

            rule.lastGeneratedDate = dayStart
        }

        try context.save()
    }
}
