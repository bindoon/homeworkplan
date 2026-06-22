import Foundation
import Observation

struct HomeSubjectGroup: Identifiable {
    let id: UUID
    let subject: Subject
    let tasks: [HomeworkTask]
}

struct HomeHistorySection: Identifiable {
    let id: Date
    let title: String
    let tasks: [HomeworkTask]
}

@Observable
@MainActor
final class HomeQueryViewModel {
    var selectedDate: Date = Date()
    var subjectGroups: [HomeSubjectGroup] = []
    var historySections: [HomeHistorySection] = []
    var expandedSubjectIDs: Set<UUID> = []
    var expandedHistoryDates: Set<Date> = []

    func setSelectedDate(_ date: Date, using repository: TaskRepository) {
        selectedDate = date
        reload(using: repository)
    }

    func reload(using repository: TaskRepository) {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let today = calendar.startOfDay(for: Date())

        do {
            let selectedTasks = try repository.fetchTasks(
                dueOn: selectedDate,
                includeCompleted: false
            )
            subjectGroups = Self.groupBySubject(tasks: selectedTasks)
            expandedSubjectIDs = Set(subjectGroups.map(\.id))

            let grouped = try repository.fetchAllTasksGroupedByDate()
            let otherDates = grouped.keys.filter { $0 != selectedDay }
            let sortedDates = Self.sortedHistoryDates(otherDates, today: today, calendar: calendar)

            historySections = sortedDates.compactMap { date in
                guard let tasks = grouped[date], !tasks.isEmpty else { return nil }
                return HomeHistorySection(
                    id: date,
                    title: Self.formatSectionTitle(date: date, calendar: calendar, today: today),
                    tasks: tasks.sorted { $0.createdAt < $1.createdAt }
                )
            }

            expandedHistoryDates = Set(
                historySections
                    .map(\.id)
                    .filter { Self.defaultHistoryExpanded(calendar: calendar, date: $0) }
            )
        } catch {
            subjectGroups = []
            historySections = []
            expandedSubjectIDs = []
            expandedHistoryDates = []
        }
    }

    func isSubjectExpanded(_ subjectID: UUID) -> Bool {
        expandedSubjectIDs.contains(subjectID)
    }

    func toggleSubject(_ subjectID: UUID) {
        if expandedSubjectIDs.contains(subjectID) {
            expandedSubjectIDs.remove(subjectID)
        } else {
            expandedSubjectIDs.insert(subjectID)
        }
    }

    func isHistoryExpanded(_ date: Date) -> Bool {
        expandedHistoryDates.contains(date)
    }

    func toggleHistorySection(_ date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        if expandedHistoryDates.contains(day) {
            expandedHistoryDates.remove(day)
        } else {
            expandedHistoryDates.insert(day)
        }
    }

    static func defaultHistoryExpanded(calendar: Calendar = .current, date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    static func sortedHistoryDates(
        _ dates: [Date],
        today: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        dates.sorted { lhs, rhs in
            if lhs == today { return true }
            if rhs == today { return false }
            if lhs > today && rhs > today { return lhs < rhs }
            if lhs < today && rhs < today { return lhs > rhs }
            return lhs > rhs
        }
    }

    static func formatSectionTitle(date: Date, calendar: Calendar, today: Date) -> String {
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

    private static func groupBySubject(tasks: [HomeworkTask]) -> [HomeSubjectGroup] {
        var groups: [UUID: (Subject, [HomeworkTask])] = [:]
        for task in tasks {
            guard let subject = task.subject else { continue }
            if var existing = groups[subject.id] {
                existing.1.append(task)
                groups[subject.id] = existing
            } else {
                groups[subject.id] = (subject, [task])
            }
        }
        return groups.values
            .sorted { $0.0.sortOrder < $1.0.sortOrder }
            .map { subject, tasks in
                HomeSubjectGroup(
                    id: subject.id,
                    subject: subject,
                    tasks: tasks.sorted { $0.createdAt < $1.createdAt }
                )
            }
    }
}
