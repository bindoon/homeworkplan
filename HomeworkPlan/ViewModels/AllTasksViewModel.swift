import Foundation
import Observation

struct AllTasksSection: Identifiable {
    let id: Date
    let title: String
    let tasks: [HomeworkTask]
}

@Observable
@MainActor
final class AllTasksViewModel {
    var sections: [AllTasksSection] = []

    func reload(using repository: TaskRepository) {
        do {
            let grouped = try repository.fetchAllTasksGroupedByDate()
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            let sortedDates = grouped.keys.sorted { lhs, rhs in
                if lhs == today { return true }
                if rhs == today { return false }
                if lhs > today && rhs > today { return lhs < rhs }
                if lhs < today && rhs < today { return lhs > rhs }
                return lhs > rhs
            }

            sections = sortedDates.compactMap { date in
                guard let tasks = grouped[date], !tasks.isEmpty else { return nil }
                return AllTasksSection(
                    id: date,
                    title: formatSectionTitle(date: date, calendar: calendar, today: today),
                    tasks: tasks.sorted { $0.createdAt < $1.createdAt }
                )
            }
        } catch {
            sections = []
        }
    }

    private func formatSectionTitle(date: Date, calendar: Calendar, today: Date) -> String {
        if calendar.isDate(date, inSameDayAs: today) {
            return "今天"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "昨天"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
