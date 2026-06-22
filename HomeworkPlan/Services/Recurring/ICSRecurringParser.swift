import Foundation

struct ICSCalendarEvent {
    let uid: String
    let summary: String
    let startDate: Date?
    let rrule: String?
}

enum ICSRecurringParser {
    static func parseEvents(from text: String, calendar: Calendar = .current) -> [ICSCalendarEvent] {
        let unfolded = unfoldLines(text)
        var events: [ICSCalendarEvent] = []
        var index = 0

        while index < unfolded.count {
            guard unfolded[index] == "BEGIN:VEVENT" else {
                index += 1
                continue
            }

            index += 1
            var uid = UUID().uuidString
            var summary = ""
            var startDate: Date?
            var rrule: String?

            while index < unfolded.count, unfolded[index] != "END:VEVENT" {
                let line = unfolded[index]
                index += 1

                if line.hasPrefix("UID:") {
                    uid = String(line.dropFirst(4))
                } else if line.hasPrefix("SUMMARY:") {
                    summary = decodeText(String(line.dropFirst(8)))
                } else if line.hasPrefix("RRULE:") {
                    rrule = String(line.dropFirst(6))
                } else if line.hasPrefix("DTSTART") {
                    startDate = parseDateLine(line, calendar: calendar) ?? startDate
                }
            }

            if index < unfolded.count {
                index += 1
            }

            let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedSummary.isEmpty, rrule != nil else { continue }

            events.append(
                ICSCalendarEvent(
                    uid: uid,
                    summary: trimmedSummary,
                    startDate: startDate,
                    rrule: rrule
                )
            )
        }

        return events
    }

    private static func unfoldLines(_ text: String) -> [String] {
        var rawLines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var unfolded: [String] = []
        for line in rawLines {
            if line.hasPrefix(" ") || line.hasPrefix("\t"), !unfolded.isEmpty {
                unfolded[unfolded.count - 1] += String(line.dropFirst())
            } else {
                unfolded.append(line)
            }
        }
        return unfolded
    }

    private static func parseDateLine(_ line: String, calendar: Calendar) -> Date? {
        let value: String
        if let separatorIndex = line.firstIndex(of: ":") {
            value = String(line[line.index(after: separatorIndex)...])
        } else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.count == 8 {
            return parseCompactDate(trimmed, calendar: calendar)
        }

        if trimmed.hasSuffix("Z") {
            return parseUTCDate(String(trimmed.dropLast()), calendar: calendar)
        }

        return parseLocalDate(trimmed, calendar: calendar)
    }

    private static func parseCompactDate(_ value: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: value)
    }

    private static func parseUTCDate(_ value: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = value.count == 8 ? "yyyyMMdd" : "yyyyMMdd'T'HHmmss"
        return formatter.date(from: value)
    }

    private static func parseLocalDate(_ value: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = value.count == 8 ? "yyyyMMdd" : "yyyyMMdd'T'HHmmss"
        return formatter.date(from: value)
    }

    private static func decodeText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
