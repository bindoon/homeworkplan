import Foundation

enum ImportContextBuilder {
    static let defaultPastDays = 7
    static let defaultFutureDays = 14
    static let defaultLimit = 50

    static func build(from tasks: [HomeworkTask], calendar: Calendar = .current) -> [ExistingTaskContextItem] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        return tasks.map { task in
            ExistingTaskContextItem(
                id: task.id.uuidString,
                subject: task.subject?.name ?? "其他",
                content: task.content,
                dueDate: formatter.string(from: calendar.startOfDay(for: task.dueDate)),
                isCompleted: task.isCompleted
            )
        }
    }

    static func encodeForPrompt(_ items: [ExistingTaskContextItem]) -> String {
        guard !items.isEmpty else { return "[]" }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard
            let data = try? encoder.encode(items),
            let json = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return json
    }
}
