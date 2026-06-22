import SwiftData
import SwiftUI

@MainActor
final class AppDependencies {
    let taskRepository: TaskRepository
    let subjectRepository: SubjectRepository

    init(context: ModelContext) {
        self.taskRepository = TaskRepository(context: context)
        self.subjectRepository = SubjectRepository(context: context)
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
