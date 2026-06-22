import Foundation
import SwiftData

@MainActor
enum SubjectDedupeService {
    static func mergeDuplicates(context: ModelContext) throws {
        let descriptor = FetchDescriptor<Subject>(
            sortBy: [SortDescriptor(\Subject.sortOrder)]
        )
        let subjects = try context.fetch(descriptor)

        var groups: [String: [Subject]] = [:]
        for subject in subjects {
            let key = subject.normalizedName.isEmpty
                ? Subject.normalizeName(subject.name)
                : subject.normalizedName
            groups[key, default: []].append(subject)
        }

        for (_, duplicates) in groups where duplicates.count > 1 {
            let sorted = duplicates.sorted { lhs, rhs in
                if lhs.isDefault != rhs.isDefault {
                    return lhs.isDefault && !rhs.isDefault
                }
                return lhs.sortOrder < rhs.sortOrder
            }
            guard let keeper = sorted.first else { continue }
            let toRemove = sorted.dropFirst()

            for duplicate in toRemove {
                let taskDescriptor = FetchDescriptor<HomeworkTask>()
                let allTasks = try context.fetch(taskDescriptor)
                for task in allTasks where task.subject?.id == duplicate.id {
                    task.subject = keeper
                }
                context.delete(duplicate)
            }
        }

        try context.save()
    }
}
