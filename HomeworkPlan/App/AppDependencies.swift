import SwiftData
import SwiftUI

@MainActor
final class AppDependencies {
    let taskRepository: TaskRepository
    let subjectRepository: SubjectRepository
    let recurringRuleRepository: RecurringRuleRepository
    let recurringTaskGenerator: RecurringTaskGenerator
    let reminderService: ReminderService
    let importRepository: ImportRepository
    let keychainService: KeychainService
    let importService: ImportService

    init(context: ModelContext) {
        self.taskRepository = TaskRepository(context: context)
        self.subjectRepository = SubjectRepository(context: context)
        self.recurringRuleRepository = RecurringRuleRepository(context: context)
        self.reminderService = ReminderService()
        self.taskRepository.reminderService = reminderService
        self.recurringTaskGenerator = RecurringTaskGenerator(
            context: context,
            taskRepository: taskRepository,
            ruleRepository: recurringRuleRepository,
            reminderService: reminderService
        )
        self.importRepository = ImportRepository(context: context)
        self.keychainService = KeychainService.shared
        self.importService = ImportService(
            importRepository: importRepository,
            taskRepository: taskRepository,
            keychainService: keychainService
        )
    }

    func seedIfNeeded() throws {
        try subjectRepository.seedDefaultsIfNeeded()
    }
}

struct AppDependenciesKey: EnvironmentKey {
    static let defaultValue: AppDependencies? = nil
}

extension EnvironmentValues {
    var appDependencies: AppDependencies? {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}
