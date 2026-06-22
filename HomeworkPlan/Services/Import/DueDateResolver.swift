import Foundation

enum DueDateResolver {
    static func resolve(
        for candidate: TaskCandidate,
        importedAt: Date = Date(),
        rawText: String? = nil,
        calendar: Calendar = .current
    ) -> Date {
        let today = calendar.startOfDay(for: importedAt)
        let content = candidate.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceText = normalizedSourceText(rawText: rawText, content: content)

        if relativeDateMentioned(in: sourceText),
           let relative = relativeDueDate(in: sourceText, from: today, calendar: calendar) {
            return relative
        }

        if explicitDateMentioned(in: sourceText), let due = candidate.dueDate {
            return calendar.startOfDay(for: due)
        }

        return today
    }

    private static func normalizedSourceText(rawText: String?, content: String) -> String {
        guard let rawText else { return content }
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return content }
        if trimmed == "[截图识图导入]" {
            return content
        }
        return trimmed
    }

    private static func relativeDateMentioned(in text: String) -> Bool {
        text.contains("大后天")
            || text.contains("后天")
            || text.contains("明天")
            || text.contains("明早")
            || text.contains("明晚")
            || text.contains("今天")
            || text.contains("今日")
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

    private static func explicitDateMentioned(in text: String) -> Bool {
        if text.range(of: #"\d{1,2}\s*月\s*\d{1,2}\s*日"#, options: .regularExpression) != nil {
            return true
        }
        if text.range(of: #"\d{4}-\d{1,2}-\d{1,2}"#, options: .regularExpression) != nil {
            return true
        }
        if text.range(of: #"\d{1,2}\s*/\s*\d{1,2}"#, options: .regularExpression) != nil {
            return true
        }
        return relativeDateMentioned(in: text)
    }
}

extension TaskCandidate {
    static func parseLocalDateString(_ value: String, calendar: Calendar = .current) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "null" else { return nil }

        let datePart = String(trimmed.prefix(10))
        let parts = datePart.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }

        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}
