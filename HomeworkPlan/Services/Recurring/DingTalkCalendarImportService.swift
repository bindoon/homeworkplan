import EventKit
import Foundation

@MainActor
final class DingTalkCalendarImportService {
    private let eventStore = EKEventStore()

    func requestCalendarAccess() async throws -> Bool {
        try await eventStore.requestFullAccessToEvents()
    }

    func fetchAvailableCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications || !$0.title.isEmpty }
            .sorted { lhs, rhs in
                let lhsScore = Self.dingTalkMatchScore(for: lhs.title)
                let rhsScore = Self.dingTalkMatchScore(for: rhs.title)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    func suggestedCalendars(from calendars: [EKCalendar]) -> [EKCalendar] {
        let dingTalkCalendars = calendars.filter { Self.isLikelyDingTalkCalendar($0.title) }
        return dingTalkCalendars.isEmpty ? calendars : dingTalkCalendars
    }

    func loadCandidates(
        from calendars: [EKCalendar],
        existingRules: [RecurringRule],
        calendar: Calendar = .current
    ) throws -> [CalendarRecurringCandidate] {
        guard !calendars.isEmpty else {
            throw DingTalkCalendarImportError.noCalendarsFound
        }

        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .year, value: 1, to: start) else {
            throw DingTalkCalendarImportError.noRecurringEventsFound
        }

        let predicate = eventStore.predicateForEvents(
            withStart: start,
            end: end,
            calendars: calendars
        )
        let events = eventStore.events(matching: predicate)

        var seenSeries = Set<String>()
        var candidates: [CalendarRecurringCandidate] = []

        for event in events {
            guard let rules = event.recurrenceRules, let firstRule = rules.first else { continue }

            let seriesKey = event.calendarItemIdentifier
            guard seenSeries.insert(seriesKey).inserted else { continue }
            guard let schedule = CalendarRecurrenceMapper.map(ekRule: firstRule) else { continue }

            let title = event.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty else { continue }

            candidates.append(
                makeCandidate(
                    id: seriesKey,
                    title: title,
                    calendarName: event.calendar.title,
                    schedule: schedule,
                    reminderTime: CalendarRecurrenceMapper.reminderTime(from: event.startDate, calendar: calendar),
                    existingRules: existingRules
                )
            )
        }

        candidates.sort { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        guard !candidates.isEmpty else {
            throw DingTalkCalendarImportError.noRecurringEventsFound
        }

        return candidates
    }

    func loadCandidates(
        fromICSData data: Data,
        existingRules: [RecurringRule],
        calendar: Calendar = .current
    ) throws -> [CalendarRecurringCandidate] {
        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .ascii) else {
            throw DingTalkCalendarImportError.invalidICSFile
        }

        let events = ICSRecurringParser.parseEvents(from: text, calendar: calendar)
        guard !events.isEmpty else {
            throw DingTalkCalendarImportError.invalidICSFile
        }

        var candidates: [CalendarRecurringCandidate] = []

        for event in events {
            guard let rrule = event.rrule,
                  let schedule = CalendarRecurrenceMapper.map(rrule: rrule) else {
                continue
            }

            candidates.append(
                makeCandidate(
                    id: event.uid,
                    title: event.summary,
                    calendarName: "ICS 文件",
                    schedule: schedule,
                    reminderTime: CalendarRecurrenceMapper.reminderTime(from: event.startDate, calendar: calendar),
                    existingRules: existingRules
                )
            )
        }

        guard !candidates.isEmpty else {
            throw DingTalkCalendarImportError.noRecurringEventsFound
        }

        return candidates
    }

    static func isLikelyDingTalkCalendar(_ title: String) -> Bool {
        dingTalkMatchScore(for: title) > 0
    }

    static func resolveSubject(for title: String, in subjects: [Subject]) -> Subject? {
        let normalized = Subject.normalizeName(title)
        if let exact = subjects.first(where: { normalized.contains($0.normalizedName) && !$0.normalizedName.isEmpty }) {
            return exact
        }
        if normalized.contains("语") {
            return subjects.first { $0.name.contains("语") }
        }
        if normalized.contains("数") {
            return subjects.first { $0.name.contains("数") }
        }
        if normalized.contains("英") {
            return subjects.first { $0.name.contains("英") }
        }
        return subjects.first
    }

    private func makeCandidate(
        id: String,
        title: String,
        calendarName: String,
        schedule: RecurringRuleSchedule,
        reminderTime: Date,
        existingRules: [RecurringRule]
    ) -> CalendarRecurringCandidate {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDuplicate = existingRules.contains { rule in
            rule.content.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedTitle
                && schedule.matchesExisting(rule)
        }

        return CalendarRecurringCandidate(
            id: id,
            title: normalizedTitle,
            calendarName: calendarName,
            schedule: schedule,
            reminderTime: reminderTime,
            isDuplicate: isDuplicate
        )
    }

    private static func dingTalkMatchScore(for title: String) -> Int {
        let normalized = title.lowercased()
        if normalized.contains("钉钉") { return 3 }
        if normalized.contains("dingtalk") { return 2 }
        if normalized.contains("ding talk") { return 2 }
        if normalized.contains("ding") { return 1 }
        return 0
    }
}
