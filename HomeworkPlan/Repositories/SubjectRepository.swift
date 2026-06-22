import Foundation
import SwiftData

@MainActor
final class SubjectRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func seedDefaultsIfNeeded() throws {
        let descriptor = FetchDescriptor<Subject>()
        let count = try context.fetchCount(descriptor)
        guard count == 0 else { return }

        let defaults: [(String, String, Int)] = [
            ("语文", "📖", 0),
            ("数学", "🔢", 1),
            ("英语", "🔤", 2),
            ("科学", "🔬", 3)
        ]

        for (name, emoji, order) in defaults {
            let subject = Subject(name: name, emoji: emoji, sortOrder: order, isDefault: true)
            context.insert(subject)
        }
        try context.save()
    }

    func fetchAll() throws -> [Subject] {
        let descriptor = FetchDescriptor<Subject>(
            sortBy: [SortDescriptor(\Subject.sortOrder)]
        )
        return try context.fetch(descriptor)
    }

    func create(name: String, emoji: String = "📚") throws -> Subject {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SubjectError.emptyName }

        let normalized = Subject.normalizeName(trimmed)
        if try findByNormalizedName(normalized) != nil {
            throw SubjectError.duplicateName
        }

        let maxOrder = try fetchAll().map(\.sortOrder).max() ?? -1
        let subject = Subject(
            name: trimmed,
            emoji: emoji.isEmpty ? "📚" : emoji,
            sortOrder: maxOrder + 1,
            isDefault: false
        )
        context.insert(subject)
        try context.save()
        return subject
    }

    func update(id: UUID, name: String, emoji: String) throws {
        guard let subject = try fetch(id: id) else { throw SubjectError.notFound }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SubjectError.emptyName }

        let normalized = Subject.normalizeName(trimmed)
        if let existing = try findByNormalizedName(normalized), existing.id != id {
            throw SubjectError.duplicateName
        }

        subject.name = trimmed
        subject.emoji = emoji.isEmpty ? "📚" : emoji
        subject.normalizedName = normalized
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let subject = try fetch(id: id) else { throw SubjectError.notFound }
        guard !subject.isDefault else { throw SubjectError.cannotDeleteDefault }
        context.delete(subject)
        try context.save()
    }

    func fetch(id: UUID) throws -> Subject? {
        let descriptor = FetchDescriptor<Subject>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    private func findByNormalizedName(_ normalized: String) throws -> Subject? {
        let descriptor = FetchDescriptor<Subject>(
            predicate: #Predicate { $0.normalizedName == normalized }
        )
        return try context.fetch(descriptor).first
    }
}
