import Foundation

enum DueDateResolver {
    static func resolve(
        for candidate: TaskCandidate,
        importedAt: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let today = calendar.startOfDay(for: importedAt)
        let text = [candidate.content, candidate.notes ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if let relative = relativeDueDate(in: text, from: today, calendar: calendar) {
            return relative
        }

        if contentReferencesExplicitDate(text), let due = candidate.dueDate {
            return calendar.startOfDay(for: due)
        }

        return today
    }

    private static func relativeDueDate(in text: String, from today: Date, calendar: Calendar) -> Date? {
        if text.contains("大后天") {
            return calendar.date(byAdding: .day, value: 3, to: today) ?? today
        }
        if text.contains("后天") {
            return calendar.date(byAdding: .day, value: 2, to: today) ?? today
        }
        if text.contains("明天") || text.contains("明早") || text.contains("明晚") {
            return calendar.date(byAdding: .day, value: 1, to: today) ?? today
        }
        if text.contains("今天") || text.contains("今日") {
            return today
        }
        return nil
    }

    private static func contentReferencesExplicitDate(_ text: String) -> Bool {
        if text.range(of: #"\d{1,2}\s*月\s*\d{1,2}\s*日"#, options: .regularExpression) != nil {
            return true
        }
        if text.range(of: #"\d{4}-\d{1,2}-\d{1,2}"#, options: .regularExpression) != nil {
            return true
        }
        if text.contains("明天") || text.contains("后天") || text.contains("今天") || text.contains("今日") {
            return true
        }
        return false
    }
}

extension TaskCandidate {
    static func parseLocalDateString(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "null" else { return nil }

        let datePart = String(trimmed.prefix(10))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: datePart) else { return nil }
        return Calendar.current.startOfDay(for: date)
    }
}
